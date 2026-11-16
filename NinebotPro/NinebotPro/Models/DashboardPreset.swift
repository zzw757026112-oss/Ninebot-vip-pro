import Foundation

/// Dashboard (instrument) presets. Values follow the original app's
/// public description. The 7-inch preset is deliberately absent on
/// iOS: the original iOS app does not support 7-inch KCP, and this
/// rebuild does not implement KCP at all.
enum DashboardPreset: String, CaseIterable, Identifiable {
    case fiveInch = "five"
    case fourPointThreeInch = "fourThree"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveInch: return "五寸（默认）"
        case .fourPointThreeInch: return "4.3 寸（实验功能）"
        }
    }

    /// Output resolution the dashboard expects.
    var width: Int {
        switch self {
        case .fiveInch: return 848
        case .fourPointThreeInch: return 480
        }
    }

    var height: Int {
        switch self {
        case .fiveInch: return 480
        case .fourPointThreeInch: return 272
        }
    }

    /// Five-inch uses H.264 over RTP; 4.3-inch uses JPEG frames over RTP.
    var usesH264: Bool {
        switch self {
        case .fiveInch: return true
        case .fourPointThreeInch: return false
        }
    }

    var defaultFPS: Int {
        switch self {
        case .fiveInch: return 20
        case .fourPointThreeInch: return 10
        }
    }

    /// Kilobits per second for H.264, JPEG quality (0...100) for JPEG.
    var defaultQuality: Int {
        switch self {
        case .fiveInch: return 2000
        case .fourPointThreeInch: return 80
        }
    }

    var note: String {
        switch self {
        case .fiveInch:
            return "五寸 848x480 曾在 KZ110 仪表上验证。"
        case .fourPointThreeInch:
            return "4.3 寸为实验功能，实际显示仍需按仪表确认兼容性。"
        }
    }
}
