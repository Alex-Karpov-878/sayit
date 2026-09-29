#!/usr/bin/env python3
"""Exercise the local signer's library restrictions in real macOS processes."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def run(*arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True)


def bundle(path, identifier, executable):
    (path / "Contents/MacOS").mkdir(parents=True)
    (path / "Contents/Info.plist").write_bytes(plistlib.dumps({
        "CFBundleIdentifier": identifier,
        "CFBundleExecutable": executable,
        "CFBundlePackageType": "APPL",
    }))


def main():
    with tempfile.TemporaryDirectory(prefix="sayit-signing-test-") as temporary:
        root = Path(temporary)
        app = root / "SayIt.app"
        bundle(app, "sh.sayit.mac.local", "SayIt")
        library = app / "Contents/Frameworks/allowed.dylib"
        library.parent.mkdir()
        denied = root / "denied.dylib"
        source = root / "library.c"
        for path, value in [(library, 42), (denied, 7)]:
            source.write_text(f"int answer(void) {{ return {value}; }}\n")
            run("clang", "-dynamiclib", str(source), "-o", str(path))
            run("codesign", "--force", "--sign", "-", str(path))
        source = root / "main.c"
        source.write_text('''#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    void *library = dlopen(argv[1], RTLD_NOW);
    if (!library) { puts(dlerror()); return 1; }
    int (*answer)(void) = dlsym(library, "answer");
    if (!answer) return 3;
    printf("%d\\n", answer());
    return 0;
}
''')
        executable = app / "Contents/MacOS/SayIt"
        run("clang", str(source), "-o", str(executable))
        executables = [executable]
        for relative, identifier, name in [
            ("Library/LaunchServices/SayItAgent.app", "sh.sayit.mac.agent", "SayItAgent"),
            ("Helpers/SayItCLI.app", "sh.sayit.mac.cli", "sayit"),
        ]:
            nested = app / "Contents" / relative
            bundle(nested, identifier, name)
            target = nested / "Contents/MacOS" / name
            shutil.copy2(executable, target)
            executables.append(target)
        helper = app / "Contents/Helpers/SayItSelectionAgent"
        shutil.copy2(executable, helper)
        executables.append(helper)
        run("python3", str(ROOT / "Scripts/sign-local-app.py"), str(app))
        for executable in executables:
            assert run(str(executable), str(library)).stdout.strip() == "42"
            result = subprocess.run([str(executable), str(denied)], capture_output=True, text=True)
            assert result.returncode == 1, result
            assert "library load contraint" in result.stdout.lower(), result.stdout
        print("PASS: all four local executables accept pinned libraries and reject unlisted libraries")


if __name__ == "__main__":
    main()
