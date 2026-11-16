import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

/// Photo / video source, fed by a SwiftUI PhotosPicker.
///
/// The picker itself is configured with `matching: nil` — no media
/// filter at all. That is deliberate: the Swift static properties
/// for the media filters are the exact symbols whose absence on
/// iOS 16.4.1 killed the original 1.0.1 build at launch (dyld
/// "Symbol not found" at launch, before any UI appeared).
/// Filtering happens here, after loading, by content type.
enum PhotoVideoSource {

    /// Load the picked item as raw data and classify it.
    /// Returns nil when the item cannot be loaded.
    static func load(item: PhotosPickerItem) async -> LoadedMedia? {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            return nil
        }
        return classify(data: data, contentTypes: item.supportedContentTypes)
    }

    /// Classify by declared content type first, then by file magic.
    static func classify(data: Data, contentTypes: [UTType]) -> LoadedMedia? {
        if let first = contentTypes.first {
            if first.conforms(to: .movie) || first.conforms(to: .video) {
                return LoadedMedia(kind: .video, data: data)
            }
            if first.conforms(to: .image) {
                return LoadedMedia(kind: .photo, data: data)
            }
        }
        // Magic-byte fallback: JPEG, PNG, HEIC, MP4/MOV.
        if data.count >= 12 {
            if data[0] == 0xFF && data[1] == 0xD8 { return LoadedMedia(kind: .photo, data: data) }
            if data[0] == 0x89 && data[1] == 0x50 { return LoadedMedia(kind: .photo, data: data) }
            let brand = String(bytes: data[4..<8], encoding: .ascii) ?? ""
            if brand == "ftyp" {
                let subtype = String(bytes: data[8..<12], encoding: .ascii) ?? ""
                if subtype.hasPrefix("heic") || subtype.hasPrefix("heix") {
                    return LoadedMedia(kind: .photo, data: data)
                }
                return LoadedMedia(kind: .video, data: data)
            }
        }
        // Unknown: treat as a photo; the image decoder will reject it
        // if it is not one, and the caller logs that.
        return LoadedMedia(kind: .photo, data: data)
    }
}

struct LoadedMedia {
    enum Kind { case photo, video }
    let kind: Kind
    let data: Data
}

/// Reads video frames from a file and hands pixel buffers to a
/// callback at the file's natural frame rate. The caller re-encodes
/// them with H264Encoder.
final class VideoFrameReader {
    private var reader: AVAssetReader?
    private var output: AVAssetReaderTrackOutput?
    private var timer: Timer?

    /// Start reading `url` (a local video file) at `fps`.
    /// Calls `onFrame` with each pixel buffer, `onFinish` at the end.
    func start(url: URL, fps: Int, onFrame: @escaping (CVPixelBuffer) -> Void,
               onFinish: @escaping () -> Void) {
        stop()
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            onFinish()
            return
        }
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            onFinish()
            return
        }
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output?.alwaysCopiesSampleData = false
        guard let reader = reader, let output = output, reader.canAdd(output) else {
            onFinish()
            return
        }
        reader.add(output)
        reader.startReading()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(max(fps, 1)), repeats: true) { _ in
            guard let sample = output.copyNextSampleBuffer(),
                  let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
                self.stop()
                onFinish()
                return
            }
            onFrame(pixelBuffer)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        reader?.cancelReading()
        reader = nil
        output = nil
    }
}
