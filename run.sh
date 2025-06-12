#!/usr/bin/env bash
set -e

# Where our binary lives
BIN=bin/imageRotationNPP

# Angle to rotate by
ANGLE=45

# Ensure artifacts folder exists
mkdir -p artifacts

# Process each PNG in data/input
for infile in data/input/*.png; do
  base=$(basename "$infile")
  outfile="artifacts/rotated_${base}"
  echo "Rotating $infile → $outfile"
  $BIN "$infile" "$outfile" $ANGLE
done

# Write proof log
echo "Processed $(ls data/input/*.png | wc -l) images" > artifacts/run.log
echo "Done. See artifacts/rotated_*.png and artifacts/run.log"
