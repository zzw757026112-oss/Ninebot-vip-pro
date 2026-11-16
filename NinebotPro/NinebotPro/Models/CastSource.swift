import Foundation

/// What the user is casting to the dashboard.
enum CastSource: String, CaseIterable, Identifiable {
    case photo = "photo"
    case video = "video"
    case camera = "camera"
    case carPlay = "carplay"
    case testImage = "test"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .photo: return "相册图片"
        case .video: return "相册视频"
        case .camera: return "摄像头"
        case .carPlay: return "CarPlay 视频流"
        case .testImage: return "测试图"
        }
    }

    var systemImage: String {
        switch self {
        case .photo: return "photo"
        case .video: return "film"
        case .camera: return "camera"
        case .carPlay: return "carplay"
        case .testImage: return "checkerboard.rectangle"
        }
    }

    /// Photo and video both come from the photo library picker.
    var needsPhotoPicker: Bool {
        switch self {
        case .photo, .video: return true
        case .camera, .carPlay, .testImage: return false
        }
    }
}

/// How a source frame is fitted to the dashboard resolution.
/// 完整 = fit, 裁满 = fill, 拉伸 = stretch.
enum CropMode: String, CaseIterable, Identifiable {
    case fit = "fit"
    case fill = "fill"
    case stretch = "stretch"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fit: return "完整"
        case .fill: return "裁满"
        case .stretch: return "拉伸"
        }
    }

    var explanation: String {
        switch self {
        case .fit: return "保留整幅画面，留黑边。"
        case .fill: return "裁掉超出部分，铺满画面。"
        case .stretch: return "改变画面比例，铺满画面。"
        }
    }
}
