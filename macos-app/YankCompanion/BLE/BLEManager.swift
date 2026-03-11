import Foundation
import CoreBluetooth
import Combine

func yankLog(_ msg: String) {
    let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let line = "[\(ts)] \(msg)\n"
    let path = "/tmp/yank_debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

enum ConnectionState: String {
    case disconnected = "Disconnected"
    case scanning = "Searching..."
    case connecting = "Connecting..."
    case connected = "Connected"
}

class BLEManager: NSObject, ObservableObject {
    // Yank! BLE Service & Characteristics (finalized by firmware team)
    static let yankServiceUUID = CBUUID(string: "b26f59c7-68f1-48c8-a4d1-676648080123")
    static let pullCharacteristicUUID = CBUUID(string: "b26f59c7-68f1-48c8-a4d1-676648080124")
    static let batteryServiceUUID = CBUUID(string: "180F")
    static let batteryCharacteristicUUID = CBUUID(string: "2A19")
    static let chargingStateCharacteristicUUID = CBUUID(string: "b26f59c7-68f1-48c8-a4d1-676648080126")

    static let deviceName = "Yank!"

    // Charging state values matching firmware
    enum PowerState: UInt8 {
        case battery = 0
        case charging = 1
        case charged = 2
    }

    @Published var connectionState: ConnectionState = .disconnected
    @Published var batteryLevel: Int?
    @Published var powerState: PowerState = .battery
    @Published var lastPullEvent: Date?
    @Published var pullCount: UInt8 = 0

    var onPullEvent: (() -> Void)?

    private var centralManager: CBCentralManager!
    private var yankPeripheral: CBPeripheral?
    private var pullCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    private var chargingCharacteristic: CBCharacteristic?
    private var shouldReconnect = true
    private var lastPullCount: UInt8 = 0
    private var scanRetryTimer: Timer?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        shouldReconnect = true

        // Clear stale characteristic references
        pullCharacteristic = nil
        batteryCharacteristic = nil
        chargingCharacteristic = nil

        // Stop any existing scan first
        centralManager.stopScan()

        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [BLEManager.yankServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )

        // Safety net: restart scan periodically in case CoreBluetooth gets stuck
        scanRetryTimer?.invalidate()
        scanRetryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.connectionState == .scanning && self.centralManager.state == .poweredOn {
                self.centralManager.stopScan()
                self.centralManager.scanForPeripherals(
                    withServices: [BLEManager.yankServiceUUID],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
            } else if self.connectionState == .connected {
                self.scanRetryTimer?.invalidate()
                self.scanRetryTimer = nil
            }
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        scanRetryTimer?.invalidate()
        scanRetryTimer = nil
        shouldReconnect = false
        if let peripheral = yankPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectionState = .disconnected
    }

    func disconnect() {
        shouldReconnect = false
        scanRetryTimer?.invalidate()
        scanRetryTimer = nil
        if let peripheral = yankPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectionState = .disconnected
    }

    // Simulate a pull event for testing
    func simulatePull() {
        lastPullEvent = Date()
        onPullEvent?()
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff:
            connectionState = .disconnected
            batteryLevel = nil
            scanRetryTimer?.invalidate()
            scanRetryTimer = nil
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Stop scanning and retry timer
        centralManager.stopScan()
        scanRetryTimer?.invalidate()
        scanRetryTimer = nil

        // Store reference (may be a new peripheral object after firmware flash)
        yankPeripheral = peripheral
        connectionState = .connecting
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        peripheral.delegate = self
        peripheral.discoverServices([BLEManager.yankServiceUUID, BLEManager.batteryServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        batteryLevel = nil
        powerState = .battery
        lastPullCount = 0

        // Clear stale references — the peripheral's GATT tables may have changed
        yankPeripheral = nil
        pullCharacteristic = nil
        batteryCharacteristic = nil
        chargingCharacteristic = nil

        if shouldReconnect {
            // Brief delay before rescanning to let the device finish rebooting
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startScanning()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        yankPeripheral = nil
        if shouldReconnect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startScanning()
            }
        }
    }
}

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == BLEManager.yankServiceUUID {
                peripheral.discoverCharacteristics([BLEManager.pullCharacteristicUUID, BLEManager.chargingStateCharacteristicUUID], for: service)
            } else if service.uuid == BLEManager.batteryServiceUUID {
                peripheral.discoverCharacteristics([BLEManager.batteryCharacteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == BLEManager.pullCharacteristicUUID {
                pullCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == BLEManager.batteryCharacteristicUUID {
                batteryCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == BLEManager.chargingStateCharacteristicUUID {
                chargingCharacteristic = characteristic
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == BLEManager.pullCharacteristicUUID {
            // Parse 2-byte payload: [pull_count, elapsed_ds]
            if let data = characteristic.value, data.count >= 2 {
                let newPullCount = data[0]
                let _ = data[1] // elapsed_ds: available for future use

                // Calculate how many pulls happened since last notification
                var eventCount = 1
                if lastPullCount != 0 && newPullCount != lastPullCount {
                    var diff = Int(newPullCount) - Int(lastPullCount)
                    if diff < 0 { diff += 255 }
                    eventCount = diff
                }
                lastPullCount = newPullCount
                pullCount = newPullCount

                yankLog("Pull: count=\(newPullCount) eventCount=\(eventCount)")

                // Fire onPullEvent for every pull, including missed ones
                lastPullEvent = Date()
                for _ in 0..<eventCount {
                    onPullEvent?()
                }
            } else {
                yankLog("Pull: short data (\(characteristic.value?.count ?? 0) bytes)")
                lastPullEvent = Date()
                onPullEvent?()
            }
        } else if characteristic.uuid == BLEManager.batteryCharacteristicUUID {
            if let data = characteristic.value, !data.isEmpty {
                batteryLevel = Int(data[0])
            }
            // Re-read charging state whenever battery updates
            if let chargingChar = chargingCharacteristic {
                peripheral.readValue(for: chargingChar)
            }
        } else if characteristic.uuid == BLEManager.chargingStateCharacteristicUUID {
            if let data = characteristic.value, !data.isEmpty {
                powerState = PowerState(rawValue: data[0]) ?? .battery
            }
        }
    }
}
