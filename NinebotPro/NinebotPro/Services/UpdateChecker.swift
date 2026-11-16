import Foundation

/// In-app update check, matching the original app's behaviour:
/// fetch the update JSON from the original release, compare
/// version/build, and offer to open the release page. Network
/// failures are logged and ignored — never a crash, never a block.
final class UpdateChecker: ObservableObject {
    @Published var availableVersion: String?
    @Published var availableBuild: Int = 0
    @Published var releaseURL: URL?

    /// The original 1.0.1 update file. The 1.1.0 rebuild is newer
    /// than 1.0.1, so this normally reports "already up to date"
    /// until a newer update file is published for the rebuild.
    static let updateURL = URL(string:
        "https://github.com/xmz28/ninebot_pro/releases/download/ios-v1.0.1/ios-update.json")!
    static let releasesURL = URL(string:
        "https://github.com/xmz28/ninebot_pro/releases")!

    private let log: AppLogStore

    init(log: AppLogStore) {
        self.log = log
    }

    struct RemoteUpdate: Decodable {
        var version: String
        var build: Int
        var minimumOSVersion: String?
        var releaseTag: String?
    }

    /// Fetch and compare. `completion(true)` when a newer version
    /// was found, `completion(false)` otherwise (including no network).
    func check(completion: @escaping (Bool) -> Void) {
        let task = URLSession.shared.dataTask(with: Self.updateURL) { data, _, error in
            if let error = error {
                self.log.log("检查更新失败（无网络或服务器不可达）：\(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            guard let data = data,
                  let remote = try? JSONDecoder().decode(RemoteUpdate.self, from: data) else {
                self.log.log("检查更新失败：更新文件无法解析")
                DispatchQueue.main.async { completion(false) }
                return
            }
            DispatchQueue.main.async {
                self.availableVersion = remote.version
                self.availableBuild = remote.build
                self.releaseURL = Self.releasesURL
                let isNewer = self.isNewer(remoteVersion: remote.version, remoteBuild: remote.build)
                if isNewer {
                    self.log.log("发现新版 \(remote.version)（构建 \(remote.build)）")
                } else {
                    self.log.log("已是最新版（远端 \(remote.version) 构建 \(remote.build)）")
                }
                completion(isNewer)
            }
        }
        task.resume()
    }

    /// Local version is 1.1.0 build 1. A remote version is newer
    /// when its version string is greater, or equal with a higher build.
    func isNewer(remoteVersion: String, remoteBuild: Int) -> Bool {
        let local = "1.1.0".split(separator: ".").compactMap { Int($0) }
        let remote = remoteVersion.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(local.count, remote.count) {
            let left = index < local.count ? local[index] : 0
            let right = index < remote.count ? remote[index] : 0
            if right > left { return true }
            if right < left { return false }
        }
        return remoteBuild > 1
    }
}
