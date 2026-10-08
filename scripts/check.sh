#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/quality
swift --version | tee work/quality/toolchain.txt
xcrun --sdk macosx --show-sdk-version | tee work/quality/sdk.txt
swift format --version | tee work/quality/formatter.txt
swift format lint --configuration .swift-format --strict --recursive Package.swift Sources Tests scripts
./scripts/lint.sh
swift scripts/project-check.swift
swift run RunTests 2>&1 | tee work/quality/tests.log
swift run PackageApp --release 2>&1 | tee work/quality/build.log
codesign --verify --deep --strict 'dist/Study Swift.app'
otool -l 'dist/Study Swift.app/Contents/MacOS/StudySwift' > work/quality/load-commands.txt
echo '정적 검사·테스트·Release 패키징 완료. 화면·생성·성능 검토는 docs/quality.md를 따르세요.'
