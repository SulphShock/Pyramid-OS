#!/bin/bash

set -e

echo "▲ Cleaning build artifacts..."
rm -rf work/ out/

echo "▲ Clean complete"
echo "▲ Building ISO..."

sudo mkarchiso -v -w work -o out .

echo "▲ ISO built: out/pyramid-os-1.0.0-x86_64.iso"
echo "▲ Computing checksums..."

sha256sum out/*.iso > out/pyramid-os-1.0.0-x86_64.iso.sha256
md5sum out/*.iso > out/pyramid-os-1.0.0-x86_64.iso.md5

echo "▲ Done."
