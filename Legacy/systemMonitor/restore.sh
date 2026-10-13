#!/bin/zsh
# Puts the parked system monitor family and fan control back in place: every
# file listed in MOVES.tsv returns to its original path, and the trimmed
# shared files are replaced by their originals in split/. The edits made to
# shared files still have to be re-applied by hand; RESTORE.md lists them.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
here=Legacy/systemMonitor
while IFS=$'\t' read -r parked original; do
    [[ -z "$parked" ]] && continue
    mkdir -p "$(dirname "$original")"
    [[ -e "$original" ]] && git rm -q -f "$original"
    git mv "$parked" "$original"
done < "$here/MOVES.tsv"
cp "$here/split/PowerSampler.swift"          Sources/Vorssaint/Services/Metrics/PowerSampler.swift
cp "$here/split/MetricFormat.swift"          Sources/Vorssaint/Services/Metrics/MetricFormat.swift
cp "$here/split/SystemInfo.swift"            Sources/Vorssaint/Services/SystemInfo.swift
cp "$here/split/MenuBarSpacingSupport.swift" Sources/Vorssaint/App/MenuBarSpacingSupport.swift
cp "$here/split/NotchAccessoryService.swift" Sources/Vorssaint/Services/Notch/NotchAccessoryService.swift
cp "$here/split/SelfTest.swift"              Sources/Vorssaint/Support/SelfTest.swift
cp Legacy/monitorDisk/split/DiskProtectionService.swift Sources/Vorssaint/Services/Metrics/DiskProtectionService.swift
echo "Files are back. Now re-apply the shared-file edits listed in $here/RESTORE.md, then swift build."
