import Foundation
import UIKit
import CoreImage

/// Generated test pattern, used by DiagnosticsView to check the
/// dashboard link without any photo or camera. Drawn with
/// UIGraphicsImageRenderer, no asset files needed.
enum TestImageSource {
    /// A 848x480 test card: colour bars, a centred cross, and a label.
    static func makeTestImage() -> CIImage? {
        let size = CGSize(width: 848, height: 480)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiImage = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.black.setFill()
            context.fill(rect)
            let bars: [UIColor] = [.white, .yellow, .cyan, .green,
                                   .magenta, .red, .blue]
            let barWidth = size.width / CGFloat(bars.count)
            for (index, colour) in bars.enumerated() {
                colour.setFill()
                context.fill(CGRect(x: CGFloat(index) * barWidth, y: 0,
                                    width: barWidth, height: size.height * 0.7))
            }
            UIColor.white.setStroke()
            context.cgContext.setLineWidth(4)
            context.cgContext.move(to: CGPoint(x: size.width / 2, y: 0))
            context.cgContext.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            context.cgContext.move(to: CGPoint(x: 0, y: size.height / 2))
            context.cgContext.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            context.cgContext.strokePath()
            let text = "Ninebot Pro  Test  848x480" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 36),
                .foregroundColor: UIColor.white
            ]
            text.draw(at: CGPoint(x: 24, y: size.height - 64), withAttributes: attributes)
        }
        guard let cgImage = uiImage.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }
}
