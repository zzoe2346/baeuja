#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/bootstrap-tools.sh
compiler=$(xcrun --find swiftc)
task_toolchain=$(dirname "$(dirname "$(dirname "$compiler")")")
# SourceKitten's discovery skips CLT. Bind it to the active compiler instead.
XCODE_DEFAULT_TOOLCHAIN_OVERRIDE="$task_toolchain" \
    ./.tools/swiftlint/0.65.1/swiftlint lint --no-cache --strict --config .swiftlint.yml
