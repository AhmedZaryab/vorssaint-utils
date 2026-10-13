// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Runs the production sampling plan against scripted surfaces and features.
enum SystemMonitorPlanTests {
    enum PowerSampler { static let hasInternalBattery = false }

    class Fixture {
        var menuPanelNeeds = SystemMonitorPanelNeeds.none
        var notchDetailNeeds = SystemMonitorPanelNeeds.none
        var fullMonitorVisible = false
        var notchVisible = false
        var notchAccessoryMonitoring = false
        static var fanTelemetryAvailable: Bool { true }
    }

    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.system-monitor-plan"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: AppFeature.fanControl.availabilityKey)
        let monitor = Monitor()

        monitor.fullMonitorVisible = false
        monitor.menuPanelNeeds = SystemMonitorPanelNeeds(system: true)
        defaults.set(true, forKey: AppFeature.monitorCPU.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.menuBarCPU)
        defaults.set(true, forKey: DefaultsKey.monitorSysCPU)
        defaults.set(true, forKey: DefaultsKey.monitorSysCPUCores)
        suite.expect(monitor.currentPlan(defaults: defaults).needCPUCores,
                     "the panel's CPU row reads every core for its per-core bars")
        defaults.set(false, forKey: DefaultsKey.monitorSysCPU)
        let menuBarCPU = monitor.currentPlan(defaults: defaults)
        suite.expect(menuBarCPU.needCPU && !menuBarCPU.needCPUCores,
                     "a CPU shown only in the menu bar does not read every core while the panel hides its CPU row")
        defaults.set(true, forKey: DefaultsKey.monitorSysCPU)
        defaults.set(false, forKey: DefaultsKey.monitorSysCPUCores)
        suite.expect(!monitor.currentPlan(defaults: defaults).needCPUCores,
                     "the Per core switch stops reading every core")
        defaults.set(true, forKey: DefaultsKey.monitorSysCPUCores)
        monitor.menuPanelNeeds = .none
        suite.expect(!monitor.currentPlan(defaults: defaults).needCPUCores,
                     "a closed panel does not read every core")
        monitor.menuPanelNeeds = SystemMonitorPanelNeeds(system: true)
        defaults.set(false, forKey: AppFeature.monitorCPU.availabilityKey)
        suite.expect(!monitor.currentPlan(defaults: defaults).needCPUCores,
                     "an uninstalled CPU monitor does not read every core")
    }
}
