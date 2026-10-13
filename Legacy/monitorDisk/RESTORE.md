# Restore monitorDisk

Disk usage, activity, SMART and the per-disk eject buttons. Its own files here: DiskSampler, DiskSupport, DiskSection, and split/DiskProtectionService.swift (the eject half; the exclusion list for Quick Toggles' Eject all disks stayed in Sources).

monitorDisk was parked with the rest of the system monitor family as one unit: it runs on the shared engine in Legacy/systemMonitor and cannot come back alone. Follow Legacy/systemMonitor/RESTORE.md (one script puts every file back, including this folder's, then re-apply the shared-file edits from the commit).
