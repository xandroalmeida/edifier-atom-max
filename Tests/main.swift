import Foundation

var assertions = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
    assertions += 1
}

let on: [UInt8] = [0xBB, 0xEC, 0xCC, 0x00, 0x03, 0x10, 0x01, 0x07, 0x8E]
let off: [UInt8] = [0xBB, 0xEC, 0xCC, 0x00, 0x03, 0x10, 0x05, 0x07, 0x92]
expect(Array(EdifierFrame(command: 0xCC, payload: []).encoded) == [0xAA, 0xEC, 0xCC, 0, 0, 0x62], "ANC query differs from hardware capture")
expect(Array(EdifierFrame(command: 0xC1, payload: [0x10, 1]).encoded) == [0xAA, 0xEC, 0xC1, 0, 2, 0x10, 1, 0x6A], "ANC on differs from capture")
expect(Array(EdifierFrame(command: 0xC1, payload: [0x10, 5]).encoded) == [0xAA, 0xEC, 0xC1, 0, 2, 0x10, 5, 0x6E], "ANC off differs from capture")
for split in 0...on.count {
    var parser = EdifierParser()
    let frames = parser.append(Data(on.prefix(split))) + parser.append(Data(on.dropFirst(split)))
    expect(frames == [EdifierFrame(command: 0xCC, payload: [0x10, 1, 7])], "Fragmented notification at \(split)")
}
var parser = EdifierParser()
expect(parser.append(Data(on + off)).count == 2, "Coalesced frames")
var corrupt = on
corrupt[8] = 0
expect(parser.append(Data(corrupt + off)) == [EdifierFrame(command: 0xCC, payload: [0x10, 5, 7])], "Checksum rejection and recovery")
expect(parser.append(Data([0, 0xBB, 0xAA, 0xBB, 0xEC, 0xCC, 0xFF, 0xFF] + on)).count == 1, "Noise and oversized frame recovery")
expect(ANCMode.decode([0x10, 1, 7]) == .strong, "Known strong ANC")
expect(ANCMode.decode([0x10, 5, 7]) == .off, "Known off")
expect(ANCMode.decode([0x10, 2, 7]) == .weak, "Comfort ANC uses code 2 in ANC16 dialect")
expect(ANCMode.decode([0x10, 4, 7]) == .ambient, "Ambient uses code 4 in ANC16 dialect")
expect(ANCMode.decode([0x10, 3, 7]) == nil, "Wind must not appear as weak ANC or off")
expect(ANCMode.decode([0x10, 6, 7]) == nil, "Do not confuse ANC16 with ANC27 dialect")
expect(Array(EdifierFrame(command: 0xC1, payload: [0x10, ANCMode.weak.rawValue]).encoded) == [0xAA, 0xEC, 0xC1, 0, 2, 0x10, 2, 0x6B], "Weak ANC frame")
expect(Array(EdifierFrame(command: 0xC1, payload: [0x10, ANCMode.ambient.rawValue]).encoded) == [0xAA, 0xEC, 0xC1, 0, 2, 0x10, 4, 0x6D], "Ambient frame")
expect(ANCMode.allCases.count == 4, "Menu provides four mutually exclusive modes")
let weakReply = parser.append(Data([0xBB, 0xEC, 0xCC, 0, 3, 0x10, 2, 7, 0x8F])).first
expect(weakReply.flatMap { ANCMode.decode($0.payload) } == .weak, "Weak ANC readback")
let ambientReply = parser.append(Data([0xBB, 0xEC, 0xCC, 0, 3, 0x10, 4, 7, 0x91])).first
expect(ambientReply.flatMap { ANCMode.decode($0.payload) } == .ambient, "Ambient readback")
expect(ANCMode.decode([0x11, 1, 7]) == nil, "Wrong ANC group")
expect(ANCMode.decode([]) == nil, "Empty state")
let name: [UInt8] = [0xBB, 0xEC, 0xC9, 0, 0x10, 0x45, 0x44, 0x49, 0x46, 0x49, 0x45, 0x52, 0x20, 0x41, 0x74, 0x6F, 0x6D, 0x20, 0x4D, 0x61, 0x78, 0x6F]
let identity = parser.append(Data(name)).first
expect(identity.flatMap { String(bytes: $0.payload, encoding: .utf8) } == "EDIFIER Atom Max", "Identity captured from real device")
// A disconnected headset can stay off for hours: retries must stop accelerating,
// pause while Bluetooth is unavailable, and become responsive after reconnection.
var backoff = ReconnectBackoff()
expect(backoff.nextDelay(canRetry: false) == nil, "No reconnect while asleep, stopping or Bluetooth off")
expect(backoff.nextDelay(canRetry: true) == 5, "First reconnect stays responsive")
expect(backoff.nextDelay(canRetry: false) == nil, "Suspension must not schedule a timer")
expect(backoff.nextDelay(canRetry: true) == 15, "Suspension does not consume a retry")
var delays: [TimeInterval] = []
for _ in 0..<100 { delays.append(backoff.nextDelay(canRetry: true)!) }
expect(delays.first == 30 && delays.last == 300, "Long offline periods use bounded backoff")
expect(delays.allSatisfy { $0 <= 300 }, "No excessive reconnect wait")
backoff.reset()
expect(backoff.nextDelay(canRetry: true) == 5, "Successful or manual connection resets backoff")

let symbols = Set(ANCMode.allCases.map { StatusPresentation(ready: true, busy: false, mode: $0).symbol })
expect(symbols.count == 4, "All four modes are distinguishable without opening the menu")
let disconnected = StatusPresentation(ready: false, busy: false, mode: .strong)
expect(disconnected.dimmed && disconnected.symbol == "headphones", "Disconnected state must not show stale ANC")
let changing = StatusPresentation(ready: true, busy: true, mode: nil)
expect(changing.symbol == "ellipsis.circle", "Changing ANC must not claim the requested mode")
let refreshing = StatusPresentation(ready: true, busy: true, mode: .ambient)
expect(refreshing.symbol == ANCMode.ambient.symbol, "Read-only refresh preserves confirmed mode")
let unknown = StatusPresentation(ready: true, busy: false, mode: nil)
expect(unknown.symbol == "questionmark.circle" && !unknown.dimmed, "Connected unknown mode differs from disconnected")

expect(FirmwareVersion.decode([2, 4, 0]) == "02.04.00", "Decode Edifier version bytes without inventing a cached firmware")
expect(FirmwareVersion.decode(Array("2.4.0".utf8)) == "2.4.0", "Accept dotted ASCII firmware")
expect(FirmwareVersion.decode(Array("2.4.0\0".utf8)) == "2.4.0", "Accept terminated version string")
expect(FirmwareVersion.decode([]) == nil, "Unavailable firmware")
expect(FirmwareVersion.decode(Array("test".utf8)) == nil, "Reject unrecognized firmware format")
expect(FirmwareVersion.decode(Array("2..4".utf8)) == nil, "Reject incomplete firmware components")
print("Passed \(assertions) checks (protocol, reconnect, status icon and firmware).")
