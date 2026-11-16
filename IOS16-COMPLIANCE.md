# iOS 16 合规检查

目标：部署目标 iOS 16.0，在 iOS 16.4.1（iPhone 14 Pro Max）上启动
不闪退。以下结果是 2026-11-16 在本机用 `grep -r -F` 对全部
21 个 Swift 源文件实际跑出来的，不是推测。

## 崩溃原因（原 1.0.1，崩溃日志 2026-11-16 20:53，incident 83F004BB）

原包在 iOS 16.4.1 上启动后约 6 毫秒被 dyld 杀掉：

```
EXC_CRASH / SIGABRT, DYLD "Symbol missing"
Symbol not found: _$s8PhotosUI14PHPickerFilterV6imagesACvgZ
  (PhotosUI.PHPickerFilter.images)
Expected in: /System/Library/Frameworks/PhotosUI.framework/PhotosUI
```

即原代码引用了 iOS 16.4.1 的 PhotosUI 里没有的 Swift 符号。
`#available` 包住调用也救不了：只要二进制里还引用这个符号，
dyld 在启动绑定时就会找它。

## 禁用清单 — grep 验证结果（Swift 源码，0 表示未出现）

| 禁用的东西 | 在源码中出现次数 | 如何避开 |
|---|---:|---|
| `PHPickerFilter`（含 `.images` / `.videos` / `.livePhotos`） | 0 | 相册选择用 `PhotosPicker(matching: nil)`，选完后按 `UTType` / 文件头判断图片还是视频（`Sources/PhotoVideoSource.swift`） |
| `.any(of:` / `.all(of:`（媒体过滤组合子） | 0 | 同上，不用过滤组合子 |
| `onChange(of:` 带 `initial:` 参数 | 0 | 只用旧版 `.onChange(of: pickedItems) { items in }`（`Views/HomeView.swift`）；首次执行放 `.onAppear` / app 入口 |
| `initial`（任何大小写，源码全文） | 0 | 同上 |
| `@Observable` / `@Bindable` / `Observation` | 0 | 全部用 `ObservableObject` + `@StateObject` / `@ObservedObject` / `@EnvironmentObject` |
| `SwiftData` | 0 | 设置用 `UserDefaults`（`Models/AppState.swift`） |
| `TipKit` | 0 | 未使用 |
| `.contentMargins` | 0 | 未使用 |
| `.scrollTargetBehavior` / `.scrollPosition` | 0 | 未使用 |
| `.inspector` | 0 | 未使用 |
| `.symbolEffect` | 0 | 未使用 |
| `.sensoryFeedback` | 0 | 未使用 |
| `.phaseAnimator` | 0 | 未使用 |
| `.onGeometryChange` | 0 | 未使用 |
| `.containerRelativeFrame` | 0 | 未使用 |
| `17.0` / `iOS 17` | 0 | 源码里不提新版本；无 `#available` 分支需要新版本 |

复核命令（在 `ios16-rebuild/` 下跑，应全部返回 0，
`onChange(of:` 除外——它只出现 1 次，是旧版用法）：

```bash
for pat in 'PHPickerFilter' 'livePhotos' '.any(of:' '.all(of:' \
  '@Observable' '@Bindable' 'Observation' 'SwiftData' 'TipKit' \
  'contentMargins' 'scrollTargetBehavior' 'scrollPosition' \
  'inspector' 'symbolEffect' 'sensoryFeedback' 'phaseAnimator' \
  'onGeometryChange' 'containerRelativeFrame' '17.0' 'iOS 17'; do
  printf '%-24s : ' "$pat"
  grep -r -F "$pat" NinebotPro --include='*.swift' | wc -l
done
grep -rn 'onChange' NinebotPro --include='*.swift'
grep -rn 'matching: nil' NinebotPro --include='*.swift'
```

## 两个导致闪退的符号，具体怎么避开

1. **媒体过滤符号**（本次崩溃的直接原因）
   - 原代码：`PhotosPicker(matching: .images)` / `.videos`。
   - 本版：`PhotosPicker(selection: $pickedItems, maxSelectionCount: 1, matching: nil)`，
     再由 `PhotoVideoSource.load(item:)` 用 `supportedContentTypes`
     和文件头（JPEG / PNG / MP4 `ftyp`）判断是图片还是视频。
2. **`.onChange(of:initial:)`**（次要风险，二进制里也有）
   - 原代码：带 `initial:` 的重载，iOS 17 才有。
   - 本版：只用 `.onChange(of:) { newValue in }`，首次执行放
     `.onAppear`（`NinebotProApp.swift` 的更新检查即如此）。

## 部署目标验证

- `NinebotPro/NinebotPro.xcodeproj/project.pbxproj`：
  `IPHONEOS_DEPLOYMENT_TARGET = 16.0`，共 4 处（项目 Debug/Release、
  Target Debug/Release）；`SWIFT_VERSION = 5.0`，共 4 处。
- `NinebotPro/NinebotPro/Info.plist`（已用 plist 解析验证）：
  `CFBundleIdentifier = com.hanlin.ninebotpro`，
  `CFBundleShortVersionString = 1.1.0`，`CFBundleVersion = 1`，
  `MinimumOSVersion = 16.0`。
- GitHub Actions 工作流（`.github/workflows/build-ios.yml`）：
  用 Xcode 15.4（可退到 16.2），不用 Xcode 26；构建后用
  PlistBuddy 断言 `MinimumOSVersion` 等于 `16.0`，不符则构建失败。
  工作流文件本身不含任何禁用 API 字符串。

## 文档中出现禁用词的情况

`README-BUILD.md` 和本文件提到 `PHPickerFilter.images` 和
`.onChange(of:initial:)`，**仅用于说明“不要用它们”**，不在任何
Swift 源码、Info.plist 或工作流里。文档里的提及不会进二进制，
不会触发 dyld 绑定。

## 仍需真机验证

静态检查只能证明“没有引用已知的坏符号”，不能证明“没有其他坏符号”。
请按 `README-BUILD.md` 的真机测试清单在 iOS 16.4.1 上逐项测。
若仍闪退，把新的 `.ips` 发回来，dyld 会报下一个缺失的符号，
按同一办法逐个修。
