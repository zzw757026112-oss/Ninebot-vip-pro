import Foundation
import Network

/// UDP sender for the dashboard link.
/// Video goes to UDP 5012, keepalive / control goes to UDP 5013,
/// matching the original app's public transport description.
final class UDPSender {
    private var videoConnection: NWConnection?
    private var controlConnection: NWConnection?
    private let queue = DispatchQueue(label: "com.hanlin.ninebotpro.udp")

    var isConnected: Bool { videoConnection != nil }

    /// Open both UDP channels to the dashboard host.
    func connect(host: String, log: AppLogStore) {
        disconnect()
        let videoEndpoint = NWEndpoint.Host(host)
        videoConnection = NWConnection(
            host: videoEndpoint,
            port: NWEndpoint.Port(integerLiteral: 5012),
            using: .udp)
        controlConnection = NWConnection(
            host: videoEndpoint,
            port: NWEndpoint.Port(integerLiteral: 5013),
            using: .udp)
        videoConnection?.start(queue: queue)
        controlConnection?.start(queue: queue)
        log.log("UDP 已连接 \(host):5012 / 5013")
    }

    func sendVideo(_ data: Data) {
        videoConnection?.send(content: data, completion: .contentProcessed { _ in })
    }

    func sendControl(_ data: Data) {
        controlConnection?.send(content: data, completion: .contentProcessed { _ in })
    }

    /// Small keepalive packet, sent about once a second while casting.
    func sendKeepalive() {
        var packet = Data([0x4E, 0x50, 0x4B, 0x41]) // "NPKA"
        var timestamp = UInt32(Date().timeIntervalSince1970).bigEndian
        packet.append(Data(bytes: &timestamp, count: 4))
        sendControl(packet)
    }

    func disconnect() {
        videoConnection?.cancel()
        controlConnection?.cancel()
        videoConnection = nil
        controlConnection = nil
    }
}
