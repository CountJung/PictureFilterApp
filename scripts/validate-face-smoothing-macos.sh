#!/bin/bash

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
INPUT_IMAGE="$ROOT/PictureFilterAppTests/Resources/Fixtures/synthetic-face.jpg"
OUTPUT_IMAGE="$BUILD_DIR/PF021-synthetic-face-retouched.png"
EXECUTABLE="$BUILD_DIR/validate-face-smoothing-macos"

mkdir -p "$BUILD_DIR"
swiftc \
    "$ROOT/PictureFilterApp/Rendering/FaceSkinSmoother.swift" \
    "$ROOT/scripts/validate-face-smoothing-macos.swift" \
    -o "$EXECUTABLE"
"$EXECUTABLE" "$INPUT_IMAGE" "$OUTPUT_IMAGE"
