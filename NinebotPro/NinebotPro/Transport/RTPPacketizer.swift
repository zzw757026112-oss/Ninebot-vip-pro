import Foundation

/// RTP packetizer for H.264 over UDP.
/// 12-byte RTP header, 90 kHz clock, payload type 96 (dynamic),
/// single-NAL packets for small NALs and FU-A fragmentation for
/// larger ones. No KCP: the 7-inch KCP mode is not implemented on iOS.
final class RTPPacketizer {
    private var sequenceNumber: UInt16 = 0
    private var timestamp: UInt32 = 0
    private let ssrc: UInt32
    private let maxPayloadSize = 1200

    init() {
        ssrc = UInt32.random(in: 1...UInt32.max)
    }

    func reset() {
        sequenceNumber = 0
        timestamp = 0
    }

    /// Advance the RTP timestamp by one frame at the given frame rate.
    func advanceFrame(fps: Int) {
        timestamp &+= UInt32(90000 / max(fps, 1))
    }

    /// Split one Annex B NAL unit (without the 00 00 00 01 start code)
    /// into RTP packets. The completion handler receives each packet.
    func packetize(nal: Data, marker: Bool, send: (Data) -> Void) {
        guard !nal.isEmpty else { return }
        if nal.count <= maxPayloadSize {
            send(makePacket(payload: nal, marker: marker))
            return
        }
        // FU-A: first byte is F | NRI | type of the original NAL.
        let nalHeader = nal[0]
        let forbidden = nalHeader & 0x80
        let nri = nalHeader & 0x60
        let nalType = nalHeader & 0x1F
        let fuIndicator = forbidden | nri | 28 // FU-A type 28
        var offset = 1
        var first = true
        while offset < nal.count {
            let remaining = nal.count - offset
            let chunk = min(remaining, maxPayloadSize - 2)
            var payload = Data()
            payload.append(fuIndicator)
            var fuHeader: UInt8 = nalType
            if first { fuHeader |= 0x80 } // Start bit
            if offset + chunk >= nal.count { fuHeader |= 0x40 } // End bit
            payload.append(fuHeader)
            payload.append(nal.subdata(in: offset..<(offset + chunk)))
            let isLast = offset + chunk >= nal.count
            send(makePacket(payload: payload, marker: marker && isLast))
            offset += chunk
            first = false
        }
    }

    private func makePacket(payload: Data, marker: Bool) -> Data {
        var packet = Data(capacity: 12 + payload.count)
        packet.append(0x80) // Version 2, no padding, no extension, no CSRC
        packet.append((marker ? 0x80 : 0x00) | 96) // Marker + dynamic PT 96
        var seq = sequenceNumber.bigEndian
        packet.append(Data(bytes: &seq, count: 2))
        sequenceNumber &+= 1
        var ts = timestamp.bigEndian
        packet.append(Data(bytes: &ts, count: 4))
        var ssrcValue = ssrc.bigEndian
        packet.append(Data(bytes: &ssrcValue, count: 4))
        packet.append(payload)
        return packet
    }
}
