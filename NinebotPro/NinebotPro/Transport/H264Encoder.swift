import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo

/// VideoToolbox output callback. VideoToolbox calls this on its own
/// queue for every compressed frame; it forwards the frame's Annex B
/// NAL units to the encoder instance passed as refcon.
private func h264OutputCallback(
    _ refcon: UnsafeMutableRawPointer?,
    _ sourceFrameRefcon: UnsafeMutableRawPointer?,
    _ status: OSStatus,
    _ infoFlags: VTEncodeInfoFlags,
    _ sampleBuffer: CMSampleBuffer?
) {
    guard status == noErr,
          let sampleBuffer = sampleBuffer,
          let refcon = refcon else { return }
    let encoder = Unmanaged<H264Encoder>.fromOpaque(refcon).takeUnretainedValue()
    // Skip frames the encoder dropped.
    guard !infoFlags.contains(.frameDropped) else { return }
    for nal in H264Encoder.nals(from: sampleBuffer) {
        encoder.onNAL?(nal)
    }
}

/// H.264 encoder built on VideoToolbox. Produces Annex B NAL units
/// which the session hands to RTPPacketizer. VideoToolbox has been
/// available since iOS 8, so this is safe on the 16.0 target.
final class H264Encoder {
    /// Called on the VideoToolbox callback queue with each Annex B
    /// NAL unit (without its start code).
    var onNAL: ((Data) -> Void)?

    private var session: VTCompressionSession?
    private var frameIndex: Int64 = 0

    /// Start (or restart) the encoder for a preset and bitrate.
    func start(width: Int, height: Int, fps: Int, bitrateKbps: Int, log: AppLogStore) {
        stop()
        frameIndex = 0
        var newSession: VTCompressionSession?
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: h264OutputCallback,
            refcon: selfPointer,
            compressionSessionOut: &newSession)
        guard status == noErr, let created = newSession else {
            log.log("H.264 编码器创建失败，状态 \(status)")
            return
        }
        session = created
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_ProfileLevel,
                             value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_AverageBitRate,
                             value: NSNumber(value: bitrateKbps * 1000))
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
                             value: NSNumber(value: fps * 2))
        VTSessionSetProperty(created, key: kVTCompressionPropertyKey_AllowFrameReordering,
                             value: kCFBooleanFalse)
        VTCompressionSessionPrepareToEncodeFrames(created)
        log.log("H.264 编码器已启动 \(width)x\(height) @ \(fps)fps \(bitrateKbps)kbps")
    }

    /// Encode one pixel buffer. Compressed output arrives through
    /// h264OutputCallback above.
    func encode(pixelBuffer: CVPixelBuffer) {
        guard let session = session else { return }
        let presentationTime = CMTime(value: frameIndex, timescale: 30)
        frameIndex += 1
        var flags = VTEncodeInfoFlags()
        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: &flags)
    }

    /// Split a CMSampleBuffer's length-prefixed (AVCC) data into
    /// individual NAL units, converting to Annex B form.
    static func nals(from sampleBuffer: CMSampleBuffer) -> [Data] {
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return [] }
        var length = 0
        var pointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil,
                                         totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
              let base = pointer else { return [] }
        let data = Data(bytes: base, count: length)
        // AVCC: each NAL is prefixed by a 4-byte big-endian length.
        var nals: [Data] = []
        var offset = 0
        while offset + 4 <= data.count {
            let nalLength = Int(data[offset]) << 24 | Int(data[offset + 1]) << 16
                | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            let start = offset + 4
            let end = min(start + nalLength, data.count)
            if end > start {
                nals.append(data.subdata(in: start..<end))
            }
            offset = end
        }
        return nals
    }

    /// Split an Annex B byte stream (00 00 00 01 start codes) into NALs.
    /// Used for CarPlay streams, which arrive as Annex B.
    static func splitAnnexB(_ data: Data) -> [Data] {
        var nals: [Data] = []
        var startCodes: [Int] = []
        var index = data.startIndex
        while index < data.endIndex - 3 {
            if data[index] == 0 && data[index + 1] == 0 && data[index + 2] == 0 && data[index + 3] == 1 {
                startCodes.append(index)
                index += 4
            } else {
                index += 1
            }
        }
        for (i, start) in startCodes.enumerated() {
            let nalStart = start + 4
            let nalEnd = i + 1 < startCodes.count ? startCodes[i + 1] : data.endIndex
            if nalEnd > nalStart {
                nals.append(data.subdata(in: nalStart..<nalEnd))
            }
        }
        return nals
    }

    func stop() {
        if let session = session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        session = nil
    }
}
