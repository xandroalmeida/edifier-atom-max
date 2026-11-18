import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = HeadphoneController()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let stateItem = NSMenuItem(title: L("Preparing Bluetooth…"), action: nil, keyEquivalent: "")
    private let batteryItem = NSMenuItem(title: L("Battery —"), action: nil, keyEquivalent: "")
    private var modeItems: [ANCMode: NSMenuItem] = [:]
    private var connectItem: NSMenuItem!
    private var refreshItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var loginApprovalItem: NSMenuItem!
    private let retryItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let aboutMenu = NSMenu(title: L("About the headphones"))
    private let modelInfo = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let firmwareInfo = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let connectionInfo = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let noiseInfo = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let batteryInfo = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var aboutIsOpen = false
    private var lastStatusSymbol: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Atom Control")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.setAccessibilityLabel(L("Atom Control — noise cancellation control"))
        menu.autoenablesItems = false
        menu.delegate = self
        let title = NSMenuItem(title: "EDIFIER Atom Max", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        stateItem.isEnabled = false
        batteryItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(batteryItem)
        menu.addItem(.separator())
        let section = NSMenuItem(title: L("Noise control"), action: nil, keyEquivalent: "")
        section.isEnabled = false
        menu.addItem(section)
        for mode in ANCMode.allCases {
            let control = item(mode.title, action: #selector(selectMode(_:)), symbol: mode.symbol)
            control.tag = Int(mode.rawValue)
            modeItems[mode] = control
        }
        menu.addItem(.separator())
        connectItem = item(L("Connect to headphones"), action: #selector(connect), symbol: "antenna.radiowaves.left.and.right")
        refreshItem = item(L("Refresh status"), action: #selector(refresh), symbol: "arrow.clockwise")
        permissionItem = item(L("Allow Bluetooth…"), action: #selector(openBluetoothPrivacy), symbol: "lock.shield")
        retryItem.isEnabled = false
        menu.addItem(retryItem)
        menu.addItem(.separator())
        loginItem = item(L("Launch at login"), action: #selector(toggleLogin), symbol: "power")
        loginApprovalItem = item(L("Approve in System Settings…"), action: #selector(openLoginSettings), symbol: "gearshape")
        let aboutItem = item(L("About the headphones"), action: nil, symbol: "info.circle")
        aboutItem.submenu = aboutMenu
        aboutMenu.autoenablesItems = false
        aboutMenu.delegate = self
        for row in [modelInfo, firmwareInfo, connectionInfo, noiseInfo, batteryInfo] {
            row.isEnabled = false
            aboutMenu.addItem(row)
        }
        aboutMenu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let appInfo = NSMenuItem(title: "Atom Control \(version)", action: nil, keyEquivalent: "")
        appInfo.isEnabled = false
        aboutMenu.addItem(appInfo)
        menu.addItem(.separator())
        let quit = item(L("Quit Atom Control"), action: #selector(quit), symbol: nil)
        quit.keyEquivalent = "q"
        statusItem.menu = menu
        controller.onChange = { [weak self] in
            guard let self else { return }
            self.render()
            if self.aboutIsOpen { self.controller.loadFirmwareIfNeeded() }
        }
        render()
        controller.start()
    }

    @discardableResult private func item(_ title: String, action: Selector?, symbol: String?) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: "")
        result.target = self
        if let symbol { result.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        menu.addItem(result)
        return result
    }

    private func render() {
        stateItem.title = controller.message
        batteryItem.title = controller.battery.map { L("Battery: %d%%", $0) } ?? L("Battery —")
        let enabled = controller.ready && !controller.busy
        for (mode, control) in modeItems {
            control.isEnabled = enabled
            control.state = controller.mode == mode ? .on : .off
        }
        connectItem.isHidden = controller.ready
        connectItem.isEnabled = !controller.busy && controller.authorized
        refreshItem.isHidden = !controller.ready
        refreshItem.isEnabled = enabled
        permissionItem.isHidden = controller.authorized
        let modeText = controller.mode?.title ?? L("Mode not confirmed")
        statusItem.button?.toolTip = "Atom Control · \(controller.message) · \(modeText)"
        let presentation = StatusPresentation(ready: controller.ready, busy: controller.busy, mode: controller.mode)
        if presentation.symbol != lastStatusSymbol {
            statusItem.button?.image = NSImage(systemSymbolName: presentation.symbol, accessibilityDescription: presentation.description)
            statusItem.button?.image?.isTemplate = true
            lastStatusSymbol = presentation.symbol
        }
        statusItem.button?.appearsDisabled = presentation.dimmed
        statusItem.button?.setAccessibilityLabel("Atom Control — \(presentation.description)")
        retryItem.isHidden = controller.reconnectAt == nil
        if let next = controller.reconnectAt {
            retryItem.title = L("Reconnecting at %@", next.formatted(date: .omitted, time: .standard))
        }
        modelInfo.title = L("Model: %@", controller.deviceName ?? L("Atom Max · not connected"))
        firmwareInfo.title = L("Firmware: %@", controller.firmwareLoading ? L("Checking…") : controller.firmware ?? L("Not reported"))
        connectionInfo.title = controller.ready ? L("Control connected via Bluetooth LE") : controller.message
        noiseInfo.title = L("Mode: %@", controller.mode?.title ?? L("Not confirmed"))
        batteryInfo.title = controller.battery.map { L("Battery: %d%%", $0) } ?? L("Battery: not reported")
        renderLoginState()
    }

    private func renderLoginState() {
        let state = SMAppService.mainApp.status
        loginItem.state = state == .enabled ? .on : state == .requiresApproval ? .mixed : .off
        loginItem.title = state == .requiresApproval ? L("Launch at login · awaiting approval") : L("Launch at login")
        loginApprovalItem.isHidden = state != .requiresApproval
    }

    @objc private func toggleLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval: try SMAppService.mainApp.unregister()
            default: try SMAppService.mainApp.register()
            }
            renderLoginState()
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            renderLoginState()
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L("Couldn’t change launch at login")
            alert.informativeText = L("Keep the app in a fixed location, such as Applications, and try again.") + "\n\n" + error.localizedDescription
            alert.addButton(withTitle: L("OK"))
            alert.runModal()
        }
    }

    @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func menuWillOpen(_ menu: NSMenu) {
        render()
        if menu === aboutMenu {
            aboutIsOpen = true
            controller.loadFirmwareIfNeeded()
        } else {
            controller.refresh()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        if menu === aboutMenu { aboutIsOpen = false }
    }
    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let mode = ANCMode(rawValue: UInt8(sender.tag)) else { return }
        controller.setMode(mode)
    }
    @objc private func connect() { controller.connect() }
    @objc private func refresh() { controller.refresh() }
    @objc private func openBluetoothPrivacy() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")!)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) { controller.stop() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

// A second launch must not create a duplicate menu item or competing BLE connection.
let bundleID = Bundle.main.bundleIdentifier ?? "br.com.local.AtomControl"
if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
