#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift format format --configuration .swift-format --in-place --recursive Package.swift Sources Tests scripts
