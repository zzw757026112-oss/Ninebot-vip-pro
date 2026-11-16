import SwiftUI

/// Diagnostics: send a test image, view the log, export / clear it.
struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showShare = false

    var body: some View {
        List {
            Section(header: Text("测试")) {
                Button("投送测试图") {
                    let settings = MirrorSession.SessionSettings(
                        host: appState.dashboardHost,
                        preset: appState.preset,
                        crop: appState.cropMode,
                        bitrateKbps: appState.bitrateKbps,
                        fps: appState.fps,
                        pauseInBackground: appState.pauseInBackground,
                        carPlayHost: appState.carPlayHost,
                        carPlayPort: appState.carPlayPort)
                    appState.session.sendTestImage(settings: settings)
                }
                Text("先投测试图：仪表有画面说明连接和预设基本正确；只有网络回应不保证仪表已经显示画面。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("日志")) {
                if appState.log.entries.isEmpty {
                    Text("暂无日志").foregroundColor(.secondary)
                } else {
                    ForEach(appState.log.entries, id: \.self) { entry in
                        Text(entry).font(.system(.footnote, design: .monospaced))
                    }
                }
            }

            Section {
                Button("导出日志") { showShare = true }
                Button("清空日志", role: .destructive) {
                    appState.log.clear()
                }
            }
        }
        .navigationTitle("诊断与日志")
        .sheet(isPresented: $showShare) {
            ShareSheet(text: appState.log.exportText)
        }
    }
}

/// UIActivityViewController wrapper for exporting the log as text.
struct ShareSheet: UIViewControllerRepresentable {
    var text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
