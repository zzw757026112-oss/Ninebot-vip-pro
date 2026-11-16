import Foundation
import CoreImage
import CoreGraphics

/// Resize / rotate / crop a source image to the dashboard preset
/// resolution, using CoreImage (available since iOS 5).
enum FrameScaler {
    private static let context = CIContext(options: nil)

    /// Scale a CIImage to the target size honouring the crop mode.
    /// - fit: scale to fit, letterbox with black.
    /// - fill: scale to cover, centre-crop the overflow.
    /// - stretch: scale non-uniformly to exactly the target size.
    static func scaled(_ image: CIImage, to width: Int, height: Int, crop: CropMode) -> CIImage {
        let source = image.extent
        guard source.width > 0, source.height > 0 else { return image }
        let targetWidth = CGFloat(width)
        let targetHeight = CGFloat(height)
        switch crop {
        case .stretch:
            let scaleX = targetWidth / source.width
            let scaleY = targetHeight / source.height
            return image
                .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                .transformed(by: CGAffineTransform(translationX: -source.origin.x * scaleX,
                                                   y: -source.origin.y * scaleY))
        case .fit:
            let scale = min(targetWidth / source.width, targetHeight / source.height)
            let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let offsetX = (targetWidth - scaled.extent.width) / 2
            let offsetY = (targetHeight - scaled.extent.height) / 2
            let translated = scaled.transformed(by: CGAffineTransform(translationX: offsetX, y: offsetY))
            let background = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
            return translated.composited(over: background)
        case .fill:
            let scale = max(targetWidth / source.width, targetHeight / source.height)
            let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let offsetX = (scaled.extent.width - targetWidth) / 2
            let offsetY = (scaled.extent.height - targetHeight) / 2
            return scaled.cropped(to: CGRect(x: offsetX, y: offsetY, width: targetWidth, height: targetHeight))
        }
    }

    /// Render a CIImage to a CGImage at its own extent.
    static func render(_ image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }

    /// Render a CIImage to JPEG data at the given quality (0...1).
    static func jpegData(_ image: CIImage, quality: CGFloat) -> Data? {
        guard let cgImage = render(image) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, "public.jpeg" as CFString, 1, nil) else { return nil }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
