# Restore connectedDevices
1. Move ConnectedDevicesStrings.swift back to Sources/Vorssaint/Core/ and USBDeviceSampler.swift back to Sources/Vorssaint/Services/Metrics/ (`git mv`), then re-add both to build.sh.
2. Re-add `case connectedDevices` to AppFeature and every switch (FeatureCatalog, FeaturePresets, FeatureVisibilitySupport, FeatureHubSettings); see `git show <cut commit>` for each line.
3. Re-add DefaultsKey menuBarConnectedDevices and monitorSysConnectedDevices, their registered defaults, and "connectedDevices" in defaultMenuBarMetricOrder.
4. Re-add the MenuBarMetric and MetricDetailKind cases, the SystemSection device row, NotchSystemView card, MonitorPanelConfig toggles, SystemMonitor snapshot/needs/usbSampler plumbing and the MonitorSamplingKind case.
5. Re-add the Tests/ blocks (SystemMonitorPlanTests, NotchTests, NotchMusicVisibilityTests, NetworkFeatureTests, MetricsFeatureTests, FeatureCatalogTests ids), then run swift build --build-tests.
