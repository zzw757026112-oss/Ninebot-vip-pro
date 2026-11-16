import Foundation
import CoreImage
import CoreVideo
import PhotosUI
import UIKit

/// The casting session: owns the UDP sender, the encoder, the
/// packetizers and the active source, and publishes status for the UI.
/// Background behaviour follows the original iOS app: entering the
/// background pauses capture and keeps the last frame on the
/// dashboard; it does not stop the session outright.
final class MirrorSession: ObservableObject {
    @Published private(set) var isCasting = false
    @Published private(set) var isPaused = false
    @Published private(set) var statusText = "未连接"
    @Published private(set) var currentSource: CastSource?

    private let log: AppLogStore
    private let sender = UDPSender()
    private let encoder = H264Encoder()
    private let packetizer = RTPPacketizer()
    private let jpegPacketizer = JPEGFramePacketizer()
    private let camera = CameraSource()
    private let carPlay = CarPlaySource()
    private let videoReader = VideoFrameReader()
    private var keepaliveTimer: Timer?
    private var photoTimer: Timer?
    private var settings: SessionSettings?

    struct SessionSettings {
        var host: String
        var preset: DashboardPreset
        var crop: CropMode
        var bitrateKbps: Int
        var fps: Int
        var pauseInBackground: Bool
        var carPlayHost: String
        var carPlayPort: Int
    }

    init(log: AppLogStore) {
        self.log = log
        encoder.onNAL = { [weak self] nal in
            self?.sendH264(nal: nal)
        }
        camera.onFrame = { [weak self] pixelBuffer in
            self?.sendPixelBuffer(pixelBuffer)
        }
        carPlay.onNAL = { [weak self] nal in
            self?.sendH264(nal: nal)
        }
        carPlay.onError = { [weak self] message in
            self?.log.log("CarPlay：\(message)")
            self?.statusText = "CarPlay：\(message)"
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    // MARK: - Start / stop

    func start(source: CastSource, settings: SessionSettings) {
        guard !isCasting else { return }
        self.settings = settings
        currentSource = source
        sender.connect(host: settings.host, log: log)
        packetizer.reset()
        jpegPacketizer.reset()
        isCasting = true
        isPaused = false
        statusText = "已连接 \(settings.host)，正在投屏：\(source.displayName)"
        log.log("开始投屏：\(source.displayName)，预设 \(settings.preset.displayName)")
        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sender.sendKeepalive()
        }
        if settings.preset.usesH264 {
            encoder.start(width: settings.preset.width, height: settings.preset.height,
                          fps: settings.fps, bitrateKbps: settings.bitrateKbps, log: log)
        }
        switch source {
        case .camera:
            camera.start(log: log) { [weak self] ok in
                if !ok { self?.stop() }
            }
        case .carPlay:
            carPlay.start(host: settings.carPlayHost, port: settings.carPlayPort, log: log)
        default:
            break
        }
    }

    func stop() {
        isCasting = false
        isPaused = false
        currentSource = nil
        keepaliveTimer?.invalidate()
        keepaliveTimer = nil
        photoTimer?.invalidate()
        photoTimer = nil
        camera.stop()
        carPlay.stop()
        videoReader.stop()
        encoder.stop()
        sender.disconnect()
        statusText = "已停止"
        log.log("投屏已停止")
    }

    /// Send the generated test image once, without starting a full
    /// cast. Used by DiagnosticsView to check the link.
    func sendTestImage(settings: SessionSettings) {
        guard let testImage = TestImageSource.makeTestImage() else {
            log.log("测试图生成失败")
            return
        }
        sender.connect(host: settings.host, log: log)
        sendStillImage(testImage, settings: settings)
        log.log("测试图已发送到 \(settings.host)")
    }

    /// Handle a photo or video picked from the library.
    /// Call while a cast for .photo / .video is active.
    func handlePickedMedia(_ media: LoadedMedia, settings: SessionSettings) {
        guard isCasting else { return }
        switch media.kind {
        case .photo:
            guard let uiImage = UIImage(data: media.data),
                  let cgImage = uiImage.cgImage else {
                log.log("图片解码失败")
                return
            }
            let ciImage = CIImage(cgImage: cgImage)
            sendStillImage(ciImage, settings: settings)
            // Re-send the still image every 2 seconds so the
            // dashboard keeps showing it.
            photoTimer?.invalidate()
            photoTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.sendStillImage(ciImage, settings: settings)
            }
        case .video:
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked-video.mp4")
            do {
                try media.data.write(to: tempURL, options: .atomic)
            } catch {
                log.log("视频保存失败：\(error.localizedDescription)")
                return
            }
            videoReader.start(url: tempURL, fps: settings.fps, onFrame: { [weak self] pixelBuffer in
                self?.sendPixelBuffer(pixelBuffer)
            }, onFinish: { [weak self] in
                self?.log.log("视频播放完毕")
            })
        }
    }

    // MARK: - Frame pipeline

    private func sendPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        guard isCasting, !isPaused, let settings = settings else { return }
        if settings.preset.usesH264 {
            // Scale first: the encoder is configured for the preset.
            // The pixel buffer is handed to the encoder as-is when it
            // already matches, otherwise the encoder is restarted
            // with the preset size on the next start.
            encoder.encode(pixelBuffer: pixelBuffer)
        } else {
            sendJPEG(pixelBuffer: pixelBuffer, settings: settings)
        }
    }

    private func sendStillImage(_ image: CIImage, settings: SessionSettings) {
        let scaled = FrameScaler.scaled(image, to: settings.preset.width,
                                        height: settings.preset.height, crop: settings.crop)
        if settings.preset.usesH264 {
            // A still image is sent as a single encoded frame: render
            // it to a pixel buffer and feed the encoder.
            guard let cgImage = FrameScaler.render(scaled),
                  let pixelBuffer = pixelBuffer(from: cgImage) else { return }
            encoder.start(width: settings.preset.width, height: settings.preset.height,
                          fps: settings.fps, bitrateKbps: settings.bitrateKbps, log: log)
            encoder.encode(pixelBuffer: pixelBuffer)
        } else {
            let quality = CGFloat(settings.preset.defaultQuality) / 100.0
            guard let jpeg = FrameScaler.jpegData(scaled, quality: quality) else { return }
            jpegPacketizer.packetize(jpeg: jpeg) { [weak self] packet in
                self?.sender.sendVideo(packet)
            }
        }
    }

    private func sendJPEG(pixelBuffer: CVPixelBuffer, settings: SessionSettings) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let scaled = FrameScaler.scaled(ciImage, to: settings.preset.width,
                                        height: settings.preset.height, crop: settings.crop)
        let quality = CGFloat(settings.preset.defaultQuality) / 100.0
        guard let jpeg = FrameScaler.jpegData(scaled, quality: quality) else { return }
        jpegPacketizer.packetize(jpeg: jpeg) { [weak self] packet in
            self?.sender.sendVideo(packet)
        }
    }

    private func sendH264(nal: Data) {
        guard isCasting, !isPaused, let settings = settings else { return }
        // NAL type 5 is an IDR (key) frame: advance the RTP
        // timestamp once per key frame so the receiver can order
        // frames on the 90 kHz clock.
        if let firstByte = nal.first, firstByte & 0x1F == 5 {
            packetizer.advanceFrame(fps: settings.fps)
        }
        packetizer.packetize(nal: nal, marker: true) { [weak self] packet in
            self?.sender.sendVideo(packet)
        }
    }

    private func pixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, cgImage.width, cgImage.height,
                                  kCVPixelFormatType_32BGRA, attributes as CFDictionary,
                                  &buffer) == kCVReturnSuccess,
              let pixelBuffer = buffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                      width: cgImage.width, height: cgImage.height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        return pixelBuffer
    }

    // MARK: - Background

    @objc private func appWillResignActive() {
        guard isCasting, settings?.pauseInBackground == true else { return }
        isPaused = true
        statusText = "已暂停（后台，保留最后画面）"
        log.log("进入后台，暂停采集，保留最后画面")
    }

    @objc private func appDidBecomeActive() {
        guard isCasting, isPaused else { return }
        isPaused = false
        statusText = "正在投屏"
        log.log("回到前台，恢复采集")
    }
}
