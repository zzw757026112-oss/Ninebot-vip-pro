import SwiftUI
import PhotosUI

/// Home: connect to the dashboard, pick a source, start/stop casting.
/// On iOS the phone joins the dashboard Wi-Fi manually in Settings;
/// this view only records the dashboard address and checks the link.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showPhotoPicker = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var pickerSource: CastSource = .photo

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("连接仪表")) {
                    HStack {
                        Text("仪表地址")
                        Spacer()
                        TextField("192.168.43.1", text: $appState.dashboardHost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("状态")
                        Spacer()
                        Text(appState.session.statusText)
                            .foregroundColor(appState.session.isCasting ? .green : .secondary)
                    }
                    Text("先在仪表开启投屏，再到系统“设置 → Wi-Fi”手动连接仪表网络，回到 App 后允许本地网络访问。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button("发送测试图") {
                        let settings = currentSettings()
                        appState.session.sendTestImage(settings: settings)
                    }
                }

                Section(header: Text("投屏内容")) {
                    ForEach(CastSource.allCases) { source in
                        Button(action: { choose(source) }) {
                            HStack {
                                Image(systemName: source.systemImage)
                                Text(source.displayName)
                                Spacer()
                                if appState.session.currentSource == source
                                    && appState.session.isCasting {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }

                Section {
                    if appState.session.isCasting {
                        Button("停止投屏", role: .destructive) {
                            appState.session.stop()
                        }
                    }
                    NavigationLink("画面设置", destination: SettingsView())
                    NavigationLink("CarPlay 服务配置", destination: CarPlayView())
                    NavigationLink("诊断与日志", destination: DiagnosticsView())
                    NavigationLink("关于与更新", destination: AboutView())
                }

                Section(header: Text("说明")) {
                    Text("仅投画面，不传声音。摄像头需在前台使用；进入后台后暂停采集、保留最后画面。手机屏幕跨 App 录制当前不支持。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Ninebot Pro")
            .photosPicker(isPresented: $showPhotoPicker,
                          selection: $pickedItems,
                          maxSelectionCount: 1,
                          matching: nil)
            .onChange(of: pickedItems) { items in
                guard let item = items.first else { return }
                Task {
                    if let media = await PhotoVideoSource.load(item: item) {
                        appState.session.handlePickedMedia(media, settings: currentSettings())
                    } else {
                        appState.log.log("相册内容加载失败")
                    }
                }
            }
            .onAppear {
                // Nothing to run on first appearance beyond what the
                // app root already does (update check).
            }
        }
    }

    private func choose(_ source: CastSource) {
        if appState.session.isCasting {
            appState.session.stop()
            return
        }
        switch source {
        case .photo, .video:
            pickerSource = source
            pickedItems = []
            showPhotoPicker = true
            // Start the cast first so the picked item has a live
            // session to feed; the picker sheet sits on top.
            appState.session.start(source: source, settings: currentSettings())
        case .testImage:
            appState.session.sendTestImage(settings: currentSettings())
        default:
            appState.session.start(source: source, settings: currentSettings())
        }
    }

    private func currentSettings() -> MirrorSession.SessionSettings {
        MirrorSession.SessionSettings(
            host: appState.dashboardHost,
            preset: appState.preset,
            crop: appState.cropMode,
            bitrateKbps: appState.bitrateKbps,
            fps: appState.fps,
            pauseInBackground: appState.pauseInBackground,
            carPlayHost: appState.carPlayHost,
            carPlayPort: appState.carPlayPort)
    }
}
