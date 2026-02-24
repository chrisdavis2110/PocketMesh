import Foundation
import Testing
@testable import MeshCore

@Suite("NewCommands")
struct NewCommandsTests {

    @Test("sendRawData format")
    func sendRawDataFormat() {
        let path = Data([0x11, 0x22])
        let payload = Data([0xAA, 0xBB, 0xCC])

        let packet = PacketBuilder.sendRawData(path: path, payload: payload)

        #expect(packet[0] == 0x19, "Command code")
        #expect(packet[1] == 0x02, "Path length")
        #expect(Data(packet[2..<4]) == path, "Path data")
        #expect(Data(packet[4...]) == payload, "Payload")
    }

    @Test("sendRawData empty path")
    func sendRawDataEmptyPath() {
        let packet = PacketBuilder.sendRawData(path: Data(), payload: Data([0xAA]))
        #expect(packet[1] == 0x00, "Empty path length")
        #expect(packet.count == 3, "command + pathLen + payload")
    }

    @Test("hasConnection format")
    func hasConnectionFormat() {
        let pubkey = Data(repeating: 0xAA, count: 32)

        let packet = PacketBuilder.hasConnection(publicKey: pubkey)

        #expect(packet.count == 33, "1 + 32 bytes")
        #expect(packet[0] == 0x1C, "Command code")
        #expect(Data(packet[1...]) == pubkey, "Public key")
    }

    @Test("getContactByKey format")
    func getContactByKeyFormat() {
        let pubkey = Data(repeating: 0xBB, count: 32)

        let packet = PacketBuilder.getContactByKey(publicKey: pubkey)

        #expect(packet.count == 33, "1 + 32 bytes")
        #expect(packet[0] == 0x1E, "Command code")
        #expect(Data(packet[1...]) == pubkey, "Public key")
    }

    @Test("getAdvertPath format")
    func getAdvertPathFormat() {
        let pubkey = Data(repeating: 0xCC, count: 32)

        let packet = PacketBuilder.getAdvertPath(publicKey: pubkey)

        #expect(packet.count == 34, "1 + 1 + 32 bytes")
        #expect(packet[0] == 0x2A, "Command code")
        #expect(packet[1] == 0x00, "Reserved byte")
        #expect(Data(packet[2...]) == pubkey, "Public key")
    }

    @Test("getTuningParams format")
    func getTuningParamsFormat() {
        let packet = PacketBuilder.getTuningParams()

        #expect(packet.count == 1)
        #expect(packet[0] == 0x2B, "Command code")
    }

    // MARK: - setPathHashMode

    @Test("setPathHashMode mode 0 (1-byte hashes)", arguments: [
        (mode: UInt8(0), label: "1-byte hashes"),
        (mode: UInt8(1), label: "2-byte hashes"),
        (mode: UInt8(2), label: "3-byte hashes"),
    ])
    func setPathHashModeFormat(mode: UInt8, label: String) {
        let packet = PacketBuilder.setPathHashMode(mode)

        #expect(packet.count == 3, "Packet should be exactly 3 bytes: cmd + reserved + mode")
        #expect(packet[0] == 0x3D, "Command code should be setPathHashMode (0x3D)")
        #expect(packet[1] == 0x00, "Reserved byte at offset 1 should be 0x00")
        #expect(packet[2] == mode, "Mode byte at offset 2 should be \(mode) (\(label))")
    }
}
