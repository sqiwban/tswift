#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(uname -s)" != Darwin ]; then
  echo "The iPhone SDK requires macOS; run builder ios build --unsigned from Linux." >&2
  exit 1
fi

configuration="${CONFIGURATION:-Debug}"
build_id="${BUILD_ID:-local}"
case "$configuration" in Debug|Release) ;; *) echo "Unsupported configuration" >&2; exit 1 ;; esac
if ! [[ "$build_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$ ]]; then
  echo "Invalid build ID" >&2
  exit 1
fi
test -f TSwift.xcodeproj/xcshareddata/xcschemes/TSwift.xcscheme
mkdir -p build

{
  xcodebuild -version
  xcrun swift --version
  xcrun --sdk iphoneos --show-sdk-version
  .tools/xcodegen-2.46.0/xcodegen/bin/xcodegen --version
  git rev-parse HEAD
} | tee build/tool-versions.txt
xcodebuild -list -json -project TSwift.xcodeproj > build/project-info.json

xcodebuild \
  -project TSwift.xcodeproj \
  -scheme TSwift \
  -configuration "$configuration" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$PWD/DerivedData" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= \
  DEVELOPMENT_TEAM= \
  build 2>&1 | tee build/xcodebuild.log

app="DerivedData/Build/Products/$configuration-iphoneos/TSwift.app"
test -d "$app"
test ! -e "$app/embedded.mobileprovision"
test ! -d "$app/_CodeSignature"
xcrun lipo -verify_arch arm64 "$app/TSwift"
if codesign -d "$app" > build/codesign.txt 2>&1; then
  echo "Expected an unsigned app, but codesign found a signature." >&2
  exit 1
fi
grep -q 'not signed at all' build/codesign.txt

python3 - "$app/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    info = plistlib.load(f)
assert info['CFBundleIdentifier'] == 'com.sqiwban.tswift', info
assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS'], info
assert info['UIDeviceFamily'] == [1], info
print('Verified: iPhoneOS, iPhone only, arm64, unsigned.')
PY

# Same unsigned IPA layout as ios-builder: Payload/<application>.app.
rm -rf build/Payload
mkdir -p build/Payload
ditto "$app" build/Payload/TSwift.app
rm -f "build/$build_id.ipa"
(cd build && zip -q -r "$build_id.ipa" Payload)
unzip -t "build/$build_id.ipa"
rm -rf build/Payload
shasum -a 256 "build/$build_id.ipa" | tee build/ipa-sha256.txt
