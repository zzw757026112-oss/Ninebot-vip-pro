import SwiftUI

/// Picture settings: dashboard preset, crop mode, bitrate, frame
/// rate, and background behaviour. Settings are saved per device
/// in UserDefaults by AppState.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section(header: Text("仪表预设")) {
                Picker("仪表", selection: $appState.preset) {
                    ForEach(DashboardPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                Text(appState.preset.note)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("七寸仪表：iOS 不支持七寸 KCP，本应用不提供七寸预设。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                HStack {
                    Text("分辨率")
                    Spacer()
                    Text("\(appState.preset.width)x\(appState.preset.height)")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("画面设置")) {
                Picker("画面模式", selection: $appState.cropMode) {
                    ForEach(CropMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(appState.cropMode.explanation)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Stepper("码率：\(appState.bitrateKbps) kbps",
                        value: $appState.bitrateKbps, in: 500...8000, step: 500)
                Stepper("帧率：\(appState.fps) fps",
                        value: $appState.fps, in: 5...30, step: 5)
            }

            Section(header: Text("后台行为")) {
                Toggle("后台暂停采集（保留最后画面）", isOn: $appState.pauseInBackground)
                Text("开启后，进入后台暂停采集，仪表保留最后画面；回到前台恢复。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("仪表地址")) {
                HStack {
                    Text("地址")
                    Spacer()
                    TextField("192.168.43.1", text: $appState.dashboardHost)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle("画面设置")
    }
}
