# Restore fanControl

Fan speeds, manual and curve control and the privileged helper. Its own files here: Services/FanControl, FanControlSection, FanControlCurveEditor, FanControlStrings, FanControlResumeTests, the helper (FanControlHelper-main.swift) and com.vorssaint.utils.fan-control.plist. Off for the owner at park time, so no helper was registered on his Mac; Tools/uninstall.sh still cleans up a helper an older build registered.

fanControl was parked with the rest of the system monitor family as one unit: it runs on the shared engine in Legacy/systemMonitor and cannot come back alone. Follow Legacy/systemMonitor/RESTORE.md (one script puts every file back, including this folder's, then re-apply the shared-file edits from the commit).
