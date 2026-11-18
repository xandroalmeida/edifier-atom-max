import Foundation

enum ANCMode: UInt8, CaseIterable {
    case strong = 0x01
    case weak = 0x02
    case ambient = 0x04
    case off = 0x05

    var title: String {
        switch self {
        case .strong: return L("Strong ANC")
        case .weak: return L("Light ANC")
        case .ambient: return L("Ambient sound")
        case .off: return L("Off")
        }
    }

    var symbol: String {
        switch self {
        case .strong: return "waveform.slash"
        case .weak: return "waveform.path"
        case .ambient: return "ear"
        case .off: return "waveform"
        }
    }

    static func decode(_ payload: [UInt8]) -> ANCMode? {
        guard payload.count >= 2, payload[0] == 0x10 else { return nil }
        return ANCMode(rawValue: payload[1])
    }
}

struct EdifierFrame: Equatable {
    let command: UInt8
    let payload: [UInt8]

    var encoded: Data {
        precondition(payload.count <= 1024)
        let bytes: [UInt8] = [0xAA, 0xEC, command, UInt8(payload.count >> 8), UInt8(payload.count & 255)] + payload
        return Data(bytes + [bytes.reduce(0, &+)])
    }
}

/// Notifications may contain partial frames, several frames, or unrelated bytes.
struct EdifierParser {
    private var buffer: [UInt8] = []

    mutating func append(_ data: Data) -> [EdifierFrame] {
        buffer.append(contentsOf: data)
        var frames: [EdifierFrame] = []
        while buffer.count >= 2 {
            guard buffer[0] == 0xBB, buffer[1] == 0xEC else {
                buffer.removeFirst()
                continue
            }
            guard buffer.count >= 5 else { break }
            let length = Int(buffer[3]) << 8 | Int(buffer[4])
            guard length <= 1024 else {
                buffer.removeFirst()
                continue
            }
            let count = length + 6
            guard buffer.count >= count else { break }
            guard buffer.prefix(count - 1).reduce(UInt8(0), &+) == buffer[count - 1] else {
                buffer.removeFirst()
                continue
            }
            frames.append(EdifierFrame(command: buffer[2], payload: Array(buffer[5..<(count - 1)])))
            buffer.removeFirst(count)
        }
        return frames
    }
}
