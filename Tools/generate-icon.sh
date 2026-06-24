#!/usr/bin/env bash
# Regenerate Sources/Resources/AppIcon.icns from Tools/GenerateIcon.swift.
#
# Renders a 1024px master PNG via SwiftUI's ImageRenderer, expands it to the
# standard .iconset sizes with `sips`, and packs them with `iconutil`. Run from
# the repo root (uses the dev-shell `swift`); commit the resulting .icns.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/Sources/Resources/AppIcon.icns"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

master="$work/icon-1024.png"
swift "$root/Tools/GenerateIcon.swift" "$master"

iconset="$work/AppIcon.iconset"
mkdir -p "$iconset"
# name           size  source-scale
gen() { sips -z "$2" "$2" "$master" --out "$iconset/$1" >/dev/null; }
gen icon_16x16.png        16
gen icon_16x16@2x.png     32
gen icon_32x32.png        32
gen icon_32x32@2x.png     64
gen icon_128x128.png      128
gen icon_128x128@2x.png   256
gen icon_256x256.png      256
gen icon_256x256@2x.png   512
gen icon_512x512.png      512
gen icon_512x512@2x.png   1024

iconutil -c icns "$iconset" -o "$out"
echo "wrote $out"
