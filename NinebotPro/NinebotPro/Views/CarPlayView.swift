import SwiftUI

/// CarPlay receiver configuration. The receiver app must provide a
/// compatible OXP interface at http://host:port/oxp/v0 and serve an
/// H.264 stream. Only the picture is cast — no audio, no touch.
struct CarPlayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var carPlayError = ""

    var body: some View {
        Form {
            Section(header: Text("CarPlay 服务")) {
                HStack {
                    Text("服务地址")
                    Spacer()
                    TextField("192.168.1.10", text: $appState.carPlayHost)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .autocapitalization(.none)
                }
                Stepper("端口：\(appState.carPlayPort)",
                        value: $appState.carPlayPort, in: 1...65535)
                Text("先在兼容的接收应用中启动服务，再填写其服务地址和端口。服务地址仅为示例，请以接收应用的设置为准。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("兼容接口说明")) {
                Text("当前使用 OXP /oxp/v0 与 H.264 视频流，仅投画面，不传声音和触控。")
                    .font(.footnote)
                Text("能在某个应用中显示 CarPlay，不代表该应用提供本工具需要的视频流接口。CarWithin、CarCast 尚未列为已验证支持。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section {
                if appState.session.isCasting
                    && appState.session.currentSource == .carPlay {
                    Button("停止 CarPlay 投屏", role: .destructive) {
                        appState.session.stop()
                    }
                } else {
                    Button("开始 CarPlay 投屏") {
                        guard !appState.carPlayHost.isEmpty else {
                            carPlayError = "请先填写服务地址"
                            return
                        }
                        carPlayError = ""
                        let settings = MirrorSession.SessionSettings(
                            host: appState.carPlayHost,
                            preset: appState.preset,
                            crop: appState.cropMode,
                            bitrateKbps: appState.bitrateKbps,
                            fps: appState.fps,
                            pauseInBackground: appState.pauseInBackground,
                            carPlayHost: appState.carPlayHost,
                            carPlayPort: appState.carPlayPort)
                        appState.session.start(source: .carPlay, settings: settings)
                    }
                }
                if !carPlayError.isEmpty {
                    Text(carPlayError).foregroundColor(.red)
                }
            }
        }
        .navigationTitle("CarPlay 配置")
    }
}
