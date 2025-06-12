#!/usr/bin/env bash
set -e

# 1) Build the rotation binary
make clean && make all

# 2) Prepare artifacts directory
mkdir -p artifacts

# 3) Rotate each PNG image by 45 degrees
for img in data/input/*.png; do
  base=$(basename "$img")
  bin/imageRotationNPP \
    --input  "$img" \
    --output "artifacts/rotated_$base" \
    --angle 45
done

# 4) Log the count
echo "Processed $(ls data/input/*.png | wc -l) images" > artifacts/run.log
