#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Draws every state of the notch island to PNGs from made-up data, for
# before-and-after design reviews. Development build only; no clicks, no
# Screen Recording, nothing read from this Mac's user. See
# docs/design/notch-render-harness.md.
#
#   scripts/render-notch.sh <output dir> [--only <name or prefix,...>] [--background <hex>]
#
# Scale: 2 pixels per point, always (a 560 pt wide page is 1120 px wide).
# Output: <output dir>/<name>.png, one per state, plus contact-sheet.png when
# python3 has Pillow. Names: 01-03 closed island, 04-22 open pages and
# notices, 30-peek-* closed-island peeks and strips, 40-grow-1..3 the opening,
# lockscreen-* the lock screen at display size, interactions-gallery when the
# gallery is in the build.
# --only picks scenes by full name, by a start of the name (30-peek,
# lockscreen) or by a start of the name after its number (music picks 04-music).
set -euo pipefail
cd "$(dirname "$0")/.."

if (( $# < 1 )) || [[ "$1" == -* ]]; then
    sed -n '10,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
fi
out="$1"; shift

binary="build/stage.noindex/Vorssaint (Developer).app/Contents/MacOS/VorssaintDeveloper"
# Rebuild the Developer variant when any source is newer than its binary.
if [[ ! -x "$binary" ]] || [[ -n "$(find Sources Resources build.sh -type f -newer "$binary" -print -quit)" ]]; then
    echo "▸ Developer build is missing or stale; building (about a minute)…"
    ./build.sh --dev >/dev/null
fi

echo "▸ Rendering into $out at 2 px per pt"
started=$SECONDS
rc=0
"$binary" --render-notch "$out" "$@" || rc=$?
echo "▸ Rendered in $(( SECONDS - started ))s"
if (( rc == 0 )) && python3 -c 'import PIL' 2>/dev/null; then
    python3 scripts/notch-contact-sheet.py "$out" && echo "▸ Contact sheet: $out/contact-sheet.png"
fi
exit $rc
