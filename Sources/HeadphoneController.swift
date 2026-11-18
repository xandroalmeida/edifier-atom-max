import AppKit
import CoreBluetooth
import OSLog

final class HeadphoneController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let service = CBUUID(string: "48091F01-1A48-11E9-AB14-D663BD873D93")
    private static let notify = CBUUID(string: "48090001-1A48-11E9-AB14-D663BD873D93")
    private static let write = CBUUID(string: "48090002-1A48-11E9-AB14-D663BD873D93")
    private let logger = Logger(subsystem: "br.com.local.AtomControl", category: "Bluetooth")
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writer: CBCharacteristic?
    private var parser = EdifierParser()
    private var deadline: DispatchWorkItem?
    private var scheduled: DispatchWorkItem?
    private var pending: (command: UInt8, completion: (EdifierFrame) -> Void)?
    private var generation = 0
    private var verified = false
    private var lastRequest = Date.distantPast
    private var lastRefresh = Date.distantPast
    private var sleeping = false
    private var stopping = false
    private var reconnect: DispatchWorkItem?
    private var backoff = ReconnectBackoff()
    private var firmwareRequested = false
    private var requestTimeout: (() -> Void)?

    var onChange: (() -> Void)?
    private(set) var message = L("Preparing Bluetooth…")
    private(set) var mode: ANCMode?
    private(set) var battery: Int?
    private(set) var ready = false
    private(set) var busy = false
    private(set) var deviceName: String?
    private(set) var firmware: String?
    private(set) var firmwareLoading = false
    private(set) var reconnectAt: Date?
    var authorized: Bool { CBCentralManager.authorization != .denied && CBCentralManager.authorization != .restricted }

    func start() {
        central = CBCentralManager(delegate: self, queue: .main)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    private func update(_ text: String) {
        message = text
        logger.info("\(text, privacy: .public)")
        onChange?()
    }

    private func armTimeout(_ seconds: Double, message: String) {
        deadline?.cancel()
        let token = generation
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            self.fail(message)
        }
        deadline = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    func connect(manually: Bool = true) {
        guard !sleeping, !stopping, central.state == .poweredOn, !busy, !ready else { return }
        if manually { backoff.reset() }
        reset()
        busy = true
        update(L("Searching for Atom Max…"))
        // A previously verified device is preferred; never persist a machine-specific UUID in source.
        if let saved = UserDefaults.standard.string(forKey: "headphoneID"),
           let id = UUID(uuidString: saved),
           let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            attach(known)
            return
        }
        if let connected = central.retrieveConnectedPeripherals(withServices: [Self.service]).first {
            attach(connected)
            return
        }
        // Some Edifier firmware advertises its name without the service UUID.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        armTimeout(12, message: L("Headphones not found. Turn them on and try connecting."))
    }

    private func scheduleReconnect() {
        guard reconnect == nil else { return }
        guard let delay = backoff.nextDelay(canRetry: !sleeping && !stopping && central.state == .poweredOn && !ready && !busy) else { return }
        reconnectAt = Date().addingTimeInterval(delay)
        let token = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            self.reconnect = nil
            self.reconnectAt = nil
            self.connect(manually: false)
        }
        reconnect = work
        logger.info("Next attempt in \(delay) seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        onChange?()
    }

    func stop() {
        stopping = true
        reset()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        central.delegate = nil
    }

    /// Optional read: lack of firmware support must never disable ANC controls.
    func loadFirmwareIfNeeded() {
        guard ready, !busy, !firmwareRequested else { return }
        firmwareRequested = true
        firmwareLoading = true
        busy = true
        onChange?()
        request(0xC6, onTimeout: { [weak self] in
            self?.firmwareLoading = false
            self?.busy = false
            self?.onChange?()
        }) { [weak self] frame in
            guard let self else { return }
            self.firmware = FirmwareVersion.decode(frame.payload)
            self.firmwareLoading = false
            self.busy = false
            self.onChange?()
        }
    }

    private func attach(_ device: CBPeripheral) {
        central.stopScan()
        peripheral = device
        device.delegate = self
        update(L("Connecting to headphones…"))
        armTimeout(15, message: L("Couldn’t connect. Close ConneX and try again."))
        central.connect(device)
    }

    func refresh() {
        guard ready, !busy, Date().timeIntervalSince(lastRefresh) > 5 else { return }
        busy = true
        onChange?()
        queryState { [weak self] in self?.queryBattery() }
    }

    func setMode(_ target: ANCMode) {
        guard ready, verified, !busy else { return }
        busy = true
        // State is unknown until the separate readback, even if the write is acknowledged.
        mode = nil
        update(L("Selecting %@…", target.title))
        request(0xC1, payload: [0x10, target.rawValue]) { [weak self] _ in
            self?.queryState {
                guard let self else { return }
                self.busy = false
                if self.mode == target {
                    self.update(L("Connected"))
                } else {
                    self.update(L("The headphones didn’t confirm the change. Try again."))
                }
            }
        }
    }

    private func queryState(completion: @escaping () -> Void) {
        request(0xCC) { [weak self] frame in
            guard let self else { return }
            guard frame.payload.count >= 2, frame.payload[0] == 0x10 else {
                self.fail(L("Unrecognized ANC response."))
                return
            }
            self.mode = ANCMode.decode(frame.payload)
            self.lastRefresh = Date()
            self.onChange?()
            completion()
        }
    }

    private func queryBattery() {
        request(0xD0) { [weak self] frame in
            guard let self else { return }
            self.battery = frame.payload.first.flatMap { $0 <= 100 ? Int($0) : nil }
            self.busy = false
            self.backoff.reset()
            self.update(L("Connected"))
        }
    }

    private func request(_ command: UInt8, payload: [UInt8] = [], onTimeout: (() -> Void)? = nil, completion: @escaping (EdifierFrame) -> Void) {
        precondition(pending == nil && scheduled == nil, "Only one BLE request at a time")
        let token = generation
        let delay = max(0, 0.35 - Date().timeIntervalSince(lastRequest))
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token, let device = self.peripheral, let writer = self.writer else { return }
            self.scheduled = nil
            self.pending = (command, completion)
            self.requestTimeout = onTimeout
            self.lastRequest = Date()
            self.deadline?.cancel()
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, self.generation == token else { return }
                self.deadline = nil
                if let optionalTimeout = self.requestTimeout {
                    self.pending = nil
                    self.requestTimeout = nil
                    optionalTimeout()
                } else {
                    self.fail(L("The headphones didn’t respond. Trying to reconnect…"))
                }
            }
            self.deadline = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)
            device.writeValue(EdifierFrame(command: command, payload: payload).encoded, for: writer, type: .withResponse)
        }
        scheduled = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func reset() {
        generation += 1
        reconnect?.cancel()
        reconnect = nil
        reconnectAt = nil
        deadline?.cancel()
        deadline = nil
        scheduled?.cancel()
        scheduled = nil
        pending = nil
        requestTimeout = nil
        central?.stopScan()
        let previous = peripheral
        peripheral = nil
        previous?.delegate = nil
        if let previous { central?.cancelPeripheralConnection(previous) }
        writer = nil
        parser = EdifierParser()
        verified = false
        ready = false
        busy = false
        mode = nil
        battery = nil
        deviceName = nil
        firmware = nil
        firmwareLoading = false
        firmwareRequested = false
    }

    private func fail(_ text: String) {
        // A cached BLE identity may become stale after re-pairing. The next
        // attempt must be able to discover the new endpoint instead of looping.
        if peripheral != nil && !verified {
            UserDefaults.standard.removeObject(forKey: "headphoneID")
        }
        reset()
        update(text)
        scheduleReconnect()
    }

    @objc private func willSleep() {
        sleeping = true
        reset()
        update(L("Mac is asleep"))
    }

    @objc private func didWake() {
        sleeping = false
        backoff.reset()
        connect(manually: false)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            backoff.reset()
            connect(manually: false)
        case .poweredOff: fail(L("Turn on Bluetooth on your Mac."))
        case .unauthorized: fail(L("Allow Bluetooth in System Settings."))
        case .unsupported: fail(L("Bluetooth is unavailable on this Mac."))
        case .resetting: fail(L("Bluetooth is restarting…"))
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover device: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard peripheral == nil else { return }
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? device.name ?? "").uppercased()
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        if name == "EDIFIER BLE" || name == "EDIFIER ATOM MAX" || services.contains(Self.service) {
            attach(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect device: CBPeripheral) {
        guard device === peripheral else { return }
        device.discoverServices([Self.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect device: CBPeripheral, error: Error?) {
        guard device === peripheral else { return }
        UserDefaults.standard.removeObject(forKey: "headphoneID")
        fail(L("Connection failed. Try connecting again."))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral device: CBPeripheral, error: Error?) {
        guard device === peripheral else { return }
        fail(L("Headphones disconnected"))
    }

    func peripheral(_ device: CBPeripheral, didDiscoverServices error: Error?) {
        guard device === peripheral else { return }
        guard error == nil, let service = device.services?.first(where: { $0.uuid == Self.service }) else {
            fail(L("Control service unavailable."))
            return
        }
        device.discoverCharacteristics([Self.notify, Self.write], for: service)
    }

    func peripheral(_ device: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard device === peripheral else { return }
        guard error == nil,
              let notify = service.characteristics?.first(where: { $0.uuid == Self.notify }),
              let write = service.characteristics?.first(where: { $0.uuid == Self.write }),
              notify.properties.contains(.notify), write.properties.contains(.write) else {
            fail(L("Incompatible Bluetooth controls."))
            return
        }
        writer = write
        device.setNotifyValue(true, for: notify)
    }

    func peripheral(_ device: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard device === peripheral, characteristic.uuid == Self.notify else { return }
        guard error == nil, characteristic.isNotifying else {
            fail(L("Couldn’t receive the headphones’ status."))
            return
        }
        deadline?.cancel()
        request(0xC9) { [weak self] frame in
            guard let self else { return }
            let name = String(bytes: frame.payload, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
            guard name == "EDIFIER Atom Max" else {
                self.fail(L("The device found is not an Atom Max."))
                return
            }
            self.verified = true
            self.deviceName = name
            UserDefaults.standard.set(device.identifier.uuidString, forKey: "headphoneID")
            self.queryState {
                self.ready = true
                self.queryBattery()
            }
        }
    }

    func peripheral(_ device: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard device === peripheral else { return }
        if error != nil { fail(L("Failed to send the command. Reconnect to check the status.")) }
    }

    func peripheral(_ device: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard device === peripheral, characteristic.uuid == Self.notify else { return }
        guard error == nil, let data = characteristic.value else {
            fail(L("Failed to read the Bluetooth response."))
            return
        }
        for frame in parser.append(data) {
            if let active = pending, active.command == frame.command {
                deadline?.cancel()
                deadline = nil
                pending = nil
                requestTimeout = nil
                active.completion(frame)
            } else if verified, !busy, frame.command == 0xCC || frame.command == 0xC1 {
                // Changes made with the physical button can arrive as notifications.
                mode = ANCMode.decode(frame.payload)
                onChange?()
            }
        }
    }
}
