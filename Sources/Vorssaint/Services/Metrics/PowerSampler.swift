// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import IOKit

/// One battery reading for the island: charge and what the adapter is doing.
/// The monitor's fuller reading (system and adapter watts from the SMC, time
/// remaining, health and cycles) is parked with it in
/// Legacy/systemMonitor/split/PowerSampler.swift.
struct PowerReading {
    var chargePercent: Int?        // current charge level
    var isCharging = false
    var externalConnected = false
    var hasBattery = false
}

/// Reads the battery from AppleSmartBattery without any special permission.
/// Anything the hardware does not expose stays nil.
final class PowerSampler {
    /// Internal-battery presence is immutable for the lifetime of a Mac boot.
    /// Resolve it once so desktops do not keep probing a service they cannot have.
    static var hasInternalBattery: Bool { batteryPresence.installed }

    /// Apple silicon desktops publish the battery service too, with
    /// BatteryInstalled false: it reports the power connection, not a battery.
    private static let batteryPresence: (service: Bool, installed: Bool) = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (false, false) }
        defer { IOObjectRelease(service) }
        let installed = IORegistryEntryCreateCFProperty(service, "BatteryInstalled" as CFString,
                                                        kCFAllocatorDefault, 0)?.takeRetainedValue()
        return (true, (installed as? Bool) != false)
    }()

    private var batteryService: io_service_t = 0

    deinit {
        if batteryService != 0 {
            IOObjectRelease(batteryService)
        }
    }

    func sample() -> PowerReading {
        var reading = PowerReading()
        let props = batteryProperties()
        if let props {
            reading.externalConnected = (props["ExternalConnected"] as? Bool) ?? false
        }
        if Self.hasInternalBattery, let props {
            reading.hasBattery = true
            reading.isCharging = (props["IsCharging"] as? Bool) ?? false
            if let capacity = props["CurrentCapacity"] as? Int,
               let maxCapacity = props["MaxCapacity"] as? Int, maxCapacity > 0 {
                reading.chargePercent = Int((Double(capacity) / Double(maxCapacity) * 100).rounded())
            }
        }
        return reading
    }

    private func batteryProperties() -> [String: Any]? {
        let service = resolvedBatteryService()
        guard service != 0 else { return nil }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let dict = properties?.takeRetainedValue() as? [String: Any]
        else {
            IOObjectRelease(service)
            batteryService = 0
            return nil
        }
        return dict
    }

    private func resolvedBatteryService() -> io_service_t {
        guard Self.batteryPresence.service else { return 0 }
        if batteryService != 0 { return batteryService }
        batteryService = IOServiceGetMatchingService(kIOMainPortDefault,
                                                     IOServiceMatching("AppleSmartBattery"))
        return batteryService
    }
}
