import Foundation

/// CarPlay video source. Connects to a compatible receiver app over
/// HTTP and reads its Annex B H.264 stream from the OXP endpoint:
///   GET http://<host>:<port>/oxp/v0
/// Picture only — no audio and no touch are sent or received.
/// The receiver app must provide a compatible OXP interface; being
/// able to display CarPlay does not by itself mean it provides one.
final class CarPlaySource: NSObject, ObservableObject, URLSessionDataDelegate {
    /// Called with each complete Annex B NAL unit from the stream.
    var onNAL: ((Data) -> Void)?
    var onError: ((String) -> Void)?

    @Published private(set) var isConnected = false

    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()

    /// Start streaming from host:port. The stream is read
    /// incrementally; complete NALs are forwarded as they arrive.
    func start(host: String, port: Int, log: AppLogStore) {
        stop()
        guard let url = URL(string: "http://\(host):\(port)/oxp/v0") else {
            log.log("CarPlay 地址无效")
            onError?("CarPlay 地址无效")
            return
        }
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        task = session?.dataTask(with: url)
        task?.resume()
        log.log("正在连接 CarPlay 服务 \(host):\(port)/oxp/v0")
    }

    func stop() {
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        buffer.removeAll()
        isConnected = false
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse, http.statusCode == 200 {
            isConnected = true
            completionHandler(.allow)
        } else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            onError?("CarPlay 服务返回 HTTP \(code)，请确认接收应用已启动 OXP 服务")
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        // Forward every complete NAL: a NAL ends where the next
        // 00 00 00 01 start code begins.
        while let nextStart = findStartCode(in: buffer, from: 4) {
            let nal = buffer.subdata(in: 0..<nextStart)
            if !nal.isEmpty {
                for unit in H264Encoder.splitAnnexB(nal) {
                    onNAL?(unit)
                }
            }
            buffer.removeSubrange(0..<nextStart)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isConnected = false
        if let error = error as NSError?, error.code != NSURLErrorCancelled {
            onError?(error.localizedDescription)
        }
    }

    private func findStartCode(in data: Data, from offset: Int) -> Int? {
        guard data.count > offset + 3 else { return nil }
        var index = offset
        while index + 3 < data.count {
            if data[index] == 0 && data[index + 1] == 0 && data[index + 2] == 0 && data[index + 3] == 1 {
                return index
            }
            index += 1
        }
        return nil
    }
}
