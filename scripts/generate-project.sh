#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(uname -s)" != Darwin ]; then
  echo "XcodeGen generation requires macOS; use the GitHub Actions workflow from Linux." >&2
  exit 1
fi

# Release metadata: https://api.github.com/repos/yonaskolb/XcodeGen/releases/tags/2.46.0
version=2.46.0
checksum=4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806
tool_dir="$PWD/.tools/xcodegen-$version"
if [ ! -x "$tool_dir/xcodegen/bin/xcodegen" ]; then
  mkdir -p "$tool_dir"
  curl --fail --show-error --location --retry 3 \
    "https://github.com/yonaskolb/XcodeGen/releases/download/$version/xcodegen.zip" \
    --output "$tool_dir/xcodegen.zip"
  printf '%s  %s\n' "$checksum" "$tool_dir/xcodegen.zip" | shasum -a 256 -c -
  unzip -q -o "$tool_dir/xcodegen.zip" -d "$tool_dir"
fi

"$tool_dir/xcodegen/bin/xcodegen" --version
"$tool_dir/xcodegen/bin/xcodegen" generate --spec project.yml
test -f TSwift.xcodeproj/xcshareddata/xcschemes/TSwift.xcscheme
