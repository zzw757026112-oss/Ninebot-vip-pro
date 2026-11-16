import SwiftUI

/// About: version, update check, usage instructions, project link.
struct AboutView: View {
    @EnvironmentObject private var appState: AppState
    @State private var checking = false
    @State private var message = ""
    @State private var showUpdateAlert = false

    var body: some View {
        Form {
            Section(header: Text("版本")) {
                HStack {
                    Text("Ninebot Pro")
                    Spacer()
                    Text("1.1.0（构建 1）").foregroundColor(.secondary)
                }
                HStack {
                    Text("系统要求")
                    Spacer()
                    Text("iOS / iPadOS 16.0+").foregroundColor(.secondary)
                }
                Text("清洁重建版：为 iOS 16.4.1 重写，未使用原 1.0.1 的代码。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("检查更新")) {
                Button(checking ? "正在检查…" : "检查更新") {
                    checking = true
                    message = ""
                    appState.updateChecker.check { isNewer in
                        checking = false
                        if isNewer {
                            showUpdateAlert = true
                        } else {
                            message = "已是最新版"
                        }
                    }
                }
                .disabled(checking)
                if !message.isEmpty {
                    Text(message).foregroundColor(.secondary)
                }
                Text("也可在前台空闲时按 24 小时间隔自动检查；投屏期间延后。访问 GitHub 需要可用的互联网连接。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("使用说明")) {
                Text("1. 在仪表开启投屏，再到系统“设置 → Wi-Fi”手动连接仪表网络。\n2. 返回 App，允许本地网络访问，刷新并核对仪表地址与预设。可在“诊断与日志”中先投送测试图。\n3. 选择相册图片、视频或摄像头。使用 CarPlay 时，先在兼容接收应用中启动服务，再填写其服务地址和端口。\n4. 在“画面设置”中调整画面参数，点击“停止投屏”结束。")
                    .font(.footnote)
            }

            Section(header: Text("项目")) {
                Link("GitHub 项目主页", destination: URL(string: "https://github.com/xmz28/ninebot_pro")!)
                Link("全部发布记录", destination: UpdateChecker.releasesURL)
                Text("本项目为独立开发的投屏工具，与九号公司无官方关联。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("关于")
        .alert("发现新版本", isPresented: $showUpdateAlert) {
            Button("前往下载") {
                if let url = appState.updateChecker.releaseURL {
                    UIApplication.shared.open(url)
                }
            }
            Button("稍后提醒", role: .cancel) { }
        } message: {
            Text("新版 \(appState.updateChecker.availableVersion ?? "") 已发布，下载后需重新自行签名安装。")
        }
    }
}
