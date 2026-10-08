#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=0.65.1
checksum=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0
destination="$PWD/.tools/swiftlint/$version"
if [[ -x "$destination/swiftlint" ]] && [[ "$("$destination/swiftlint" version)" == "$version" ]]; then
    exit 0
fi
archive=$(mktemp -t study-swiftlint)
trap 'rm -f "$archive"' EXIT
curl --fail --location --silent --show-error \
    "https://github.com/realm/SwiftLint/releases/download/$version/portable_swiftlint.zip" \
    --output "$archive"
actual=$(shasum -a 256 "$archive" | awk '{print $1}')
[[ "$actual" == "$checksum" ]] || { echo 'SwiftLint 체크섬 불일치' >&2; exit 1; }
mkdir -p "$destination"
unzip -q -o "$archive" -d "$destination"
[[ "$("$destination/swiftlint" version)" == "$version" ]]
