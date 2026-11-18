import Foundation

/// No repeating timer: each failed attempt schedules at most one successor.
struct ReconnectBackoff {
    private var attempt = 0
    private static let delays: [TimeInterval] = [5, 15, 30, 60, 120, 300]

    mutating func nextDelay(canRetry: Bool) -> TimeInterval? {
        guard canRetry else { return nil }
        let delay = Self.delays[attempt]
        attempt = min(attempt + 1, Self.delays.count - 1)
        return delay
    }

    mutating func reset() { attempt = 0 }
}

struct StatusPresentation {
    let symbol: String
    let description: String
    let dimmed: Bool

    init(ready: Bool, busy: Bool, mode: ANCMode?) {
        dimmed = !ready && !busy
        if let mode, ready {
            symbol = mode == .off ? "headphones" : mode.symbol
            description = mode.title
        } else if busy {
            symbol = "ellipsis.circle"
            description = "Conectando ou atualizando o fone"
        } else {
            symbol = ready ? "questionmark.circle" : "headphones"
            description = ready ? "Modo não confirmado" : "Fone desconectado"
        }
    }
}

enum FirmwareVersion {
    static func decode(_ payload: [UInt8]) -> String? {
        // Some firmware reports dotted ASCII; older Edifier firmware reports
        // three version bytes, displayed in hexadecimal by mEDIFIER.
        if let text = String(bytes: payload, encoding: .utf8) {
            let clean = text.trimmingCharacters(in: .controlCharacters)
            let parts = clean.split(separator: ".", omittingEmptySubsequences: false)
            if (2...4).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) {
                return clean
            }
        }
        guard payload.count == 3 else { return nil }
        return payload.map { String(format: "%02X", $0) }.joined(separator: ".")
    }
}
