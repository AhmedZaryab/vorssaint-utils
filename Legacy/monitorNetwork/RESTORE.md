# Restore monitorNetwork

Network speeds, per-app traffic, local addresses and the speed test (also the island's Speed test control). Its own files here: NetworkSampler, NetworkProcessSupport, NetworkAddressService, SpeedTest, NetworkSection and their tests.

monitorNetwork was parked with the rest of the system monitor family as one unit: it runs on the shared engine in Legacy/systemMonitor and cannot come back alone. Follow Legacy/systemMonitor/RESTORE.md (one script puts every file back, including this folder's, then re-apply the shared-file edits from the commit).
