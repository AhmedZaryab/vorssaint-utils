// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Carbon.HIToolbox
import Combine
import CoreAudio
import CoreGraphics
import Darwin
import Foundation
import ImageIO

/// What is left of the metrics tests after the system monitor was parked in
/// Legacy/systemMonitor (the full original is MetricsFeatureTests.swift there):
/// byte formatting, the island's battery symbol and accessory batteries.
enum MetricsFeatureTests {
    static func run(_ suite: TestSuite) {
        func expectEqual(_ actual: String, _ expected: String, _ label: String,
                         file: StaticString = #filePath, line: UInt = #line) {
            suite.expect(actual == expected, "\(label): got \(actual), expected \(expected)",
                         file: file, line: line)
        }
        let originalLocale = MetricFormat.locale
        // MARK: Byte formatting

        // Pinned, because everything below reads a decimal point and this
        // machine's region is only one of the ones the app ships for.
        MetricFormat.locale = Locale(identifier: "en_US_POSIX")
        expectEqual(MetricFormat.bytes(0), "0 B", "bytes zero")
        expectEqual(MetricFormat.bytes(512), "512 B", "bytes < 1K")
        expectEqual(MetricFormat.bytes(1024), "1.0 KB", "bytes 1K")
        expectEqual(MetricFormat.bytes(1536), "1.5 KB", "bytes 1.5K")
        // Nine of the fifteen languages here are spoken where a decimal is
        // written with a comma, and the panel wrote a point at everyone.
        MetricFormat.locale = Locale(identifier: "pt_BR")
        expectEqual(MetricFormat.bytes(1536), "1,5 KB", "a comma region reads its own decimal")
        MetricFormat.locale = Locale(identifier: "en_US_POSIX")
        expectEqual(MetricFormat.bytes(10 * 1024), "10 KB", "bytes 10K drops decimal")
        expectEqual(MetricFormat.bytes(1024 * 1024), "1.0 MB", "bytes 1M")
        expectEqual(MetricFormat.bytes(3 * 1024 * 1024 * 1024), "3.0 GB", "bytes 3G")
        // A value that only reaches the next unit after rounding used to print as
        // "1,024 KB", one unit behind the compact menu-bar form, which already
        // promoted that edge. Both must name the unit the number reads as.
        expectEqual(MetricFormat.bytes(1023), "1023 B", "bytes just under a kilobyte stay in bytes")
        expectEqual(MetricFormat.bytes(1_048_063), "1023 KB", "a total just short of the kilobyte edge stays in kilobytes")
        expectEqual(MetricFormat.bytes(1_048_064), "1.0 MB", "a total that rounds to a megabyte is shown in megabytes")
        expectEqual(MetricFormat.bytes(1_048_575), "1.0 MB", "a megabyte total is never labelled 1,024 KB")
        expectEqual(MetricFormat.bytes(1_000_000_000), "954 MB", "byte totals keep the binary 1024 base")
        expectEqual(MetricFormat.diskBytes(245_107_195_904), "245 GB", "disk bytes use decimal storage units")
        expectEqual(MetricFormat.diskBytes(1_000_204_845_056), "1.0 TB", "disk bytes show decimal terabytes")
        expectEqual(MetricFormat.diskBytes(123_456_789_000), "123 GB", "disk bytes match Finder-style GB")
        expectEqual(MetricFormat.diskBytes(1_000_000_000), "1.0 GB", "disk bytes keep the decimal 1000 base")

        // MARK: Battery

        expectEqual(BatteryPowerSupport.menuBarSymbol(percent: 80,
                                                      isCharging: false,
                                                      externalConnected: true),
                    "battery.100.bolt",
                    "a charge held at a limit still reads as external power")
        expectEqual(BatteryPowerSupport.menuBarSymbol(percent: 100,
                                                      isCharging: false,
                                                      externalConnected: true),
                    "battery.100.bolt",
                    "a full battery on its adapter still reads as external power")
        expectEqual(BatteryPowerSupport.menuBarSymbol(percent: 42,
                                                      isCharging: true,
                                                      externalConnected: true),
                    "battery.100.bolt",
                    "a charge in progress keeps the bolt")
        expectEqual(BatteryPowerSupport.menuBarSymbol(percent: 42,
                                                      isCharging: true,
                                                      externalConnected: false),
                    "battery.100.bolt",
                    "a charge reported before its adapter keeps the bolt")
        expectEqual(BatteryPowerSupport.menuBarSymbol(percent: 42,
                                                      isCharging: false,
                                                      externalConnected: false),
                    "battery.50",
                    "an unplugged Mac shows its charge level, never the bolt")
        expectEqual(BatteryPowerSupport.menuBarSymbol(percent: 5,
                                                      isCharging: false,
                                                      externalConnected: false),
                    "battery.0",
                    "an unplugged Mac keeps the level thresholds it always had")

        suite.expect(BatteryPowerSupport.state(isCharging: false,
                                               externalConnected: true,
                                               hasBattery: true) == .externalPower,
               "a stopped charge on the adapter is external power, not battery power")
        suite.expect(BatteryPowerSupport.state(isCharging: true,
                                               externalConnected: true,
                                               hasBattery: true) == .charging,
               "a charge in progress is named as charging")
        suite.expect(BatteryPowerSupport.state(isCharging: false,
                                               externalConnected: false,
                                               hasBattery: true) == .onBattery,
               "an unplugged Mac with a battery is on battery power")
        suite.expect(BatteryPowerSupport.state(isCharging: false,
                                               externalConnected: false,
                                               hasBattery: false) == .unavailable,
               "a Mac with no battery and no adapter reading has nothing to report")
        suite.expect(BatteryPowerSupport.state(isCharging: true,
                                               externalConnected: false,
                                               hasBattery: true) == .charging,
               "a charge claimed without an adapter flag is still never battery power")

        // MARK: Peripheral battery helpers

        suite.expect(PeripheralBatterySupport.percent(from: "87%") == 87,
               "peripheral battery parses percentage strings")
        suite.expect(PeripheralBatterySupport.percent(from: NSNumber(value: 62.4)) == 62,
               "peripheral battery rounds numeric values")
        suite.expect(PeripheralBatterySupport.percent(from: 140) == nil,
               "peripheral battery ignores invalid percentages")
        suite.expect(PeripheralBatterySupport.percent(from: NSNumber(value: UInt64.max)) == nil,
               "peripheral battery returns nil rather than trapping on a huge device number")
        suite.expect(PeripheralBatterySupport.percent(from: NSNumber(value: Double.greatestFiniteMagnitude)) == nil,
               "peripheral battery returns nil rather than trapping on the largest finite number")
        suite.expect(PeripheralBatterySupport.percent(from: "1e300") == nil,
               "peripheral battery returns nil rather than trapping on an absurd percentage string")
        suite.expect(PeripheralBatterySupport.percent(from: 55) == 55,
               "peripheral battery keeps an integer percentage")
        suite.expect(PeripheralBatterySupport.percent(from: "80") == 80,
               "peripheral battery parses a bare percentage string")
        suite.expect(PeripheralBatterySupport.percent(from: NSNumber(value: 42.6)) == 43,
               "peripheral battery rounds a fractional percentage up")
        suite.expect(PeripheralBatterySupport.percent(from: NSNumber(value: 42.4)) == 42,
               "peripheral battery rounds a fractional percentage down")
        suite.expect(PeripheralBatterySupport.percent(from: -5) == nil,
               "peripheral battery ignores a negative percentage")
        suite.expect(PeripheralBatterySupport.percent(from: 0) == 0,
               "peripheral battery keeps an empty battery as zero rather than nil")
        suite.expect(PeripheralBatterySupport.percent(from: 100) == 100,
               "peripheral battery keeps a full battery")
        suite.expect(PeripheralBatterySupport.percent(from: Double.nan) == nil,
               "peripheral battery ignores a not-a-number reading")
        suite.expect(PeripheralBatterySupport.percent(from: "abc") == nil,
               "peripheral battery ignores unreadable text")
        suite.expect(PeripheralBatterySupport.percent(from: nil) == nil,
               "peripheral battery ignores a missing value")
        let usageMouse = [["DeviceUsagePage": 1, "DeviceUsage": 2]]
        suite.expect(PeripheralBatterySupport.kind(product: "Wireless Device",
                                             primaryUsagePage: nil,
                                             primaryUsage: nil,
                                             usagePairs: usageMouse) == .mouse,
               "peripheral battery infers mouse from HID usage")
        suite.expect(PeripheralBatterySupport.kind(product: "soundcore Space Q45",
                                             minorType: "Headset",
                                             primaryUsagePage: nil,
                                             primaryUsage: nil,
                                             usagePairs: []) == .audio,
               "peripheral battery infers Bluetooth headsets as audio devices")
        let bluetoothJSON = Data("""
        {"SPBluetoothDataType":[{"device_connected":[
          {"soundcore Space Q45":{"device_address":"F4:9D:8A:A2:4C:12","device_batteryLevelMain":"100%","device_minorType":"Headset"}},
          {"AirPods Pro":{"device_address":"E5:04:BE:68:C2:93","device_batteryLevelCase":"88%","device_batteryLevelLeft":"92%","device_batteryLevelRight":"90%"}},
          {"Travel Pointer":{"device_address":"F0:00:00:00:00:01","device_minorType":"Mouse"}}
        ],"device_not_connected":[
          {"Old Mouse":{"device_address":"00:00:00:00:00:00","device_batteryLevelMain":"12%","device_minorType":"Mouse"}}
        ]}]}
        """.utf8)
        let bluetoothDevices = PeripheralBatterySupport.bluetoothDevices(fromSystemProfilerJSON: bluetoothJSON)
        suite.expect(bluetoothDevices.contains(PeripheralBatteryDevice(id: "Bluetooth:F4:9D:8A:A2:4C:12",
                                                                 name: "soundcore Space Q45",
                                                                 percent: 100,
                                                                 kind: .audio)),
               "peripheral battery parses connected Bluetooth headset battery")
        suite.expect(bluetoothDevices.contains(PeripheralBatteryDevice(id: "Bluetooth:E5:04:BE:68:C2:93",
                                                                 name: "AirPods Pro",
                                                                 percent: 88,
                                                                 kind: .audio)),
               "peripheral battery uses the lowest connected AirPods component")
        suite.expect(!bluetoothDevices.contains { $0.name == "Old Mouse" },
               "peripheral battery ignores disconnected Bluetooth devices")
        let bluetoothKinds = PeripheralBatterySupport.bluetoothKindsByName(
            fromSystemProfilerJSON: bluetoothJSON
        )
        suite.expect(bluetoothKinds["travel pointer"] == .mouse,
               "peripheral battery keeps the kind of connected devices without profiler charge data")
        let gattDevices = PeripheralBatterySupport.mergingBluetoothReadings(
            [
                BluetoothBatteryReading(id: "pointer", name: "Travel Pointer", percent: 73),
                BluetoothBatteryReading(id: "pointer", name: "Renamed Pointer", percent: 64),
                BluetoothBatteryReading(id: "duplicate", name: "soundcore space q45", percent: 17),
                BluetoothBatteryReading(id: "invalid", name: "Invalid Accessory", percent: 101),
            ],
            into: bluetoothDevices,
            knownKinds: bluetoothKinds
        )
        suite.expect(gattDevices.contains(PeripheralBatteryDevice(id: "BluetoothGATT:pointer",
                                                            name: "Travel Pointer",
                                                            percent: 73,
                                                            kind: .mouse)),
               "peripheral battery adds a standard Bluetooth battery reading with its known kind")
        suite.expect(gattDevices.first { $0.name.caseInsensitiveCompare("soundcore Space Q45") == .orderedSame }?.percent == 100,
               "peripheral battery keeps richer profiler data instead of a duplicate standard reading")
        suite.expect(!gattDevices.contains { $0.name == "Renamed Pointer" },
               "peripheral battery keeps one row per Bluetooth identity")
        suite.expect(!gattDevices.contains { $0.name == "Invalid Accessory" },
               "peripheral battery rejects invalid standard Bluetooth percentages")
        let keyboard = PeripheralBatteryDevice(id: "keyboard",
                                               name: "Magic Keyboard",
                                               percent: 78,
                                               kind: .keyboard)
        let mouse = PeripheralBatteryDevice(id: "mouse",
                                            name: "Magic Mouse",
                                            percent: 24,
                                            kind: .mouse)
        suite.expect(PeripheralBatterySupport.sorted([keyboard, mouse]).map(\.id) == ["mouse", "keyboard"],
               "peripheral battery devices sort by lowest charge first")
        suite.expect(PeripheralBatteryRefreshPolicy.shouldStartBluetoothRefresh(
            now: 300,
            lastStartedAt: -.greatestFiniteMagnitude,
            lastFinishedAt: -.greatestFiniteMagnitude,
            isRunning: false,
            interval: 300
        ), "peripheral Bluetooth refresh starts when no cache exists")
        suite.expect(!PeripheralBatteryRefreshPolicy.shouldStartBluetoothRefresh(
            now: 400,
            lastStartedAt: 300,
            lastFinishedAt: 305,
            isRunning: true,
            interval: 300
        ), "peripheral Bluetooth refresh is single-flight")
        suite.expect(!PeripheralBatteryRefreshPolicy.shouldStartBluetoothRefresh(
            now: 500,
            lastStartedAt: 300,
            lastFinishedAt: 305,
            isRunning: false,
            interval: 300
        ), "peripheral Bluetooth refresh respects its cache interval")
        suite.expect(PeripheralBatteryRefreshPolicy.shouldStartBluetoothRefresh(
            now: 606,
            lastStartedAt: 300,
            lastFinishedAt: 305,
            isRunning: false,
            interval: 300
        ), "peripheral Bluetooth refresh runs again only after the interval")

        MetricFormat.locale = originalLocale
    }
}
