import Foundation
import AVFoundation

/// Live camera source. The camera must stay in the foreground:
/// leaving the foreground stops capture (original iOS behaviour).
/// Only video is captured; audio is not sent to the dashboard.
final class CameraSource: NSObject, ObservableObject {
    var onFrame: ((CVPixelBuffer) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.hanlin.ninebotpro.camera")

    var isRunning: Bool { session.isRunning }

    /// Request access and start the session. Calls completion with
    /// true when the camera is running.
    func start(log: AppLogStore, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession(log: log, completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.startSession(log: log, completion: completion)
                    } else {
                        log.log("摄像头权限被拒绝")
                        completion(false)
                    }
                }
            }
        default:
            log.log("摄像头权限未授予，请在系统设置中开启")
            completion(false)
        }
    }

    private func startSession(log: AppLogStore, completion: @escaping (Bool) -> Void) {
        queue.async {
            guard !self.session.isRunning else {
                DispatchQueue.main.async { completion(true) }
                return
            }
            self.session.beginConfiguration()
            self.session.sessionPreset = .vga640x480
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    log.log("找不到可用的后置摄像头")
                    completion(false)
                }
                return
            }
            self.session.addInput(input)
            self.output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.output.alwaysDiscardsLateVideoFrames = true
            self.output.setSampleBufferDelegate(self, queue: self.queue)
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
            self.session.startRunning()
            DispatchQueue.main.async {
                log.log("摄像头已启动")
                completion(true)
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

extension CameraSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}
