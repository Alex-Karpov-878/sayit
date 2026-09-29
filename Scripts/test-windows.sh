#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
derived_data="$project_root/Build/DerivedData-Local"
products="$derived_data/Build/Products"
module_cache="$project_root/Build/ModuleCache"
sign_identity="${SAYIT_SIGN_IDENTITY:--}"

# Library validation rejects ad-hoc dynamic frameworks. Keep hardened runtime
# enabled and require a signing identity shared by the app and its frameworks.
if [ "$sign_identity" = "-" ]; then
    echo "Set SAYIT_SIGN_IDENTITY to a valid Apple signing identity for UI tests." >&2
    echo "Ad-hoc builds compile, but macOS rejects their frameworks under hardened runtime." >&2
    exit 2
fi

if pgrep -f "$products/Release/SayIt.app/Contents/MacOS/SayIt" >/dev/null 2>&1; then
    echo "Quit the local build before running window tests." >&2
    exit 2
fi

mkdir -p "$module_cache" "$project_root/Build/SwiftPMCache"

# Match the app build's explicit trust gate for pinned package plugins.
plugin_validation_option=
if [ "${SAYIT_TRUST_REVIEWED_PLUGINS:-0}" = "1" ]; then
    plugin_validation_option=-skipPackagePluginValidation
fi

xcodegen generate --spec "$project_root/project.yml" --project "$project_root"
CLANG_MODULE_CACHE_PATH="$module_cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
XDG_CACHE_HOME="$project_root/Build/SwiftPMCache" \
xcodebuild \
    -quiet \
    -project "$project_root/SayIt.xcodeproj" \
    -scheme SayItWindowTests \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$project_root/Build/SourcePackages" \
    ${plugin_validation_option:+"$plugin_validation_option"} \
    -onlyUsePackageVersionsFromResolvedFile \
    -destination "platform=macOS,arch=arm64" \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    OTHER_CFLAGS="\$(inherited) -ffile-prefix-map=$project_root=." \
    OTHER_CPLUSPLUSFLAGS="\$(inherited) -ffile-prefix-map=$project_root=." \
    OTHER_SWIFT_FLAGS="\$(inherited) -file-prefix-map $project_root=." \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    ENABLE_HARDENED_RUNTIME=YES \
    SAYIT_APP_BUNDLE_IDENTIFIER=sh.sayit.mac.local \
    SAYIT_APP_DISPLAY_NAME="Say It Local" \
    SAYIT_SELECTION_BUNDLE_IDENTIFIER=sh.sayit.mac.selection-helper.local \
    SAYIT_SELECTION_DISPLAY_NAME="Say It Local Selected-Text Helper" \
    SAYIT_LOCAL_SWIFT_FLAG=-DSAYIT_LOCAL_BUILD \
    SWIFT_COMPILATION_MODE=singlefile \
    build-for-testing

# Sign local bundles after building without an app-group provisioning profile.
# The test runner also needs a valid resource seal before macOS can launch it.
"$project_root/Scripts/sign-embedded-code.sh" "$products/Release/SayIt.app" "$sign_identity"
codesign --force --sign "$sign_identity" --options runtime \
    --identifier sh.sayit.mac.selection-helper.local \
    "$products/Release/SayIt.app/Contents/Helpers/SayItSelectionAgent"
codesign --force --sign "$sign_identity" --options runtime \
    --entitlements "$project_root/Config/SayItLocal.entitlements" \
    "$products/Release/SayIt.app"
codesign --force --deep --sign "$sign_identity" "$products/Release/SayItUITests-Runner.app"
codesign --verify --deep --strict "$products/Release/SayIt.app"
codesign --verify --deep --strict "$products/Release/SayItUITests-Runner.app"

xcodebuild \
    -quiet \
    -project "$project_root/SayIt.xcodeproj" \
    -scheme SayItWindowTests \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    -destination "platform=macOS,arch=arm64" \
    "$@" \
    test-without-building
