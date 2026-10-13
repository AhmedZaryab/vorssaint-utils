# Restore monitorGPU

GPU usage and GPU temperature. It has no files of its own; the reading lives in Legacy/systemMonitor/SystemMonitor.swift.

monitorGPU was parked with the rest of the system monitor family as one unit: it runs on the shared engine in Legacy/systemMonitor and cannot come back alone. Follow Legacy/systemMonitor/RESTORE.md (one script puts every file back, including this folder's, then re-apply the shared-file edits from the commit).
