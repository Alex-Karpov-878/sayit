#!/usr/bin/env python3
"""Sign a local arm64 app with exact library hashes instead of a Team ID."""
import argparse
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MACH_MAGICS = {b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"}


def library_hashes(app):
    hashes = set()
    for path in sorted(app.rglob("*")):
        if path.is_symlink() or not path.is_file():
            continue
        with path.open("rb") as source:
            if source.read(4) not in MACH_MAGICS:
                continue
        header = subprocess.check_output(["otool", "-hv", str(path)], text=True)
        if not re.search(r"\bDYLIB\b", header):
            continue
        subprocess.run(["codesign", "--verify", "--strict", str(path)], check=True)
        signature = subprocess.run(
            ["codesign", "-d", "--arch", "arm64", "--verbose=4", str(path)],
            check=True, capture_output=True, text=True,
        ).stderr
        match = re.search(r"^CDHash=([0-9a-f]{40})$", signature, re.MULTILINE)
        if not match:
            raise RuntimeError(f"Missing arm64 code-directory hash: {path}")
        hashes.add(bytes.fromhex(match[1]))
    if not hashes:
        raise RuntimeError("No signed bundled libraries found")
    return sorted(hashes)


def sign_local_app(app):
    app = app.resolve(strict=True)
    with (app / "Contents/Info.plist").open("rb") as source:
        identifier = plistlib.load(source)["CFBundleIdentifier"]
    if identifier not in {"sh.sayit.mac.local", "sh.sayit.mac.model-audit"}:
        raise ValueError("Local signing only supports local and audit app identifiers")

    # Finalize libraries first. Do not re-sign them after recording their hashes.
    subprocess.run([str(ROOT / "Scripts/sign-embedded-code.sh"), str(app), "-"], check=True)
    with tempfile.TemporaryDirectory(prefix="sayit-local-sign-") as temporary:
        directory = Path(temporary)
        constraint = directory / "libraries.plist"
        constraint.write_bytes(plistlib.dumps({"cdhash": {"$in": library_hashes(app)}}))
        subprocess.run(["codesign", "--validate-constraint", str(constraint)], check=True)
        helper_entitlements = directory / "helper.plist"
        local_entitlements = {"com.apple.security.cs.disable-library-validation": True}
        helper_entitlements.write_bytes(plistlib.dumps(local_entitlements))
        app_entitlements = directory / "app.plist"
        with (ROOT / "Config/SayItLocal.entitlements").open("rb") as source:
            local_entitlements.update(plistlib.load(source))
        app_entitlements.write_bytes(plistlib.dumps(local_entitlements))
        targets = [
            app / "Contents/Library/LaunchServices/SayItAgent.app",
            app / "Contents/Helpers/SayItCLI.app",
            app / "Contents/Helpers/SayItSelectionAgent",
            app,
        ]
        for target in targets:
            identifier_options = []
            if target.name == "SayItSelectionAgent":
                identifier_options = ["--identifier", identifier.replace(
                    "sh.sayit.mac", "sh.sayit.mac.selection-helper", 1
                )]
            subprocess.run([
                "codesign", "--force", "--sign", "-", "--options", "runtime",
                "--preserve-metadata=identifier", *identifier_options,
                "--entitlements", str(app_entitlements if target == app else helper_entitlements),
                "--library-constraint", str(constraint), str(target),
            ], check=True)
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    sign_local_app(parser.parse_args().app)
