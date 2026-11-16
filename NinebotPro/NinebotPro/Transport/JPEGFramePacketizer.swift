import Foundation

/// JPEG frame packetizer for the 4.3-inch preset.
/// Each frame is JPEG-compressed by the caller, then sliced into
/// chunks that fit in one UDP datagram. Each chunk carries a tiny
/// header so the receiver can reassemble the frame: magic "NPJ",
/// frame id (4 bytes), chunk index (2), chunk count (2), then data.
/// Every frame is independently decodable, as in the original.
final class JPEGFramePacketizer {
    private var frameID: UInt32 = 0
    private let maxChunkSize = 1200

    func reset() { frameID = 0 }

    /// Slice one JPEG frame into datagrams.
    func packetize(jpeg: Data, send: (Data) -> Void) {
        frameID &+= 1
        let totalChunks = max(1, (jpeg.count + maxChunkSize - 1) / maxChunkSize)
        for chunkIndex in 0..<totalChunks {
            let start = chunkIndex * maxChunkSize
            let end = min(start + maxChunkSize, jpeg.count)
            var packet = Data()
            packet.append(contentsOf: [0x4E, 0x50, 0x4A]) // "NPJ"
            var frame = frameID.bigEndian
            packet.append(Data(bytes: &frame, count: 4))
            var index = UInt16(chunkIndex).bigEndian
            packet.append(Data(bytes: &index, count: 2))
            var count = UInt16(totalChunks).bigEndian
            packet.append(Data(bytes: &count, count: 2))
            packet.append(jpeg.subdata(in: start..<end))
            send(packet)
        }
    }
}
