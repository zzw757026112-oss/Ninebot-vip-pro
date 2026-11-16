# Ninebot Pro — 清洁重建版（iOS 16.0+）构建说明

## 这是什么

这是 Ninebot Pro iOS 版的**清洁重建（clean-room）源码**，版本 1.1.0（构建 1），
Bundle ID `com.hanlin.ninebotpro`，部署目标 **iOS 16.0**，目标是在
iOS 16.4.1 的 iPhone 14 Pro Max 上正常运行。

它不是原 1.0.1 的改包：原仓库里没有 iOS 源码，1.0.1 的 IPA 只改
`MinimumOSVersion` 也救不回来。崩溃日志已确认，原 1.0.1 在启动时就被
dyld 杀掉，原因是它引用了 iOS 16.4.1 的 PhotosUI 里没有的 Swift 符号
`PhotosUI.PHPickerFilter.images`，以及 iOS 17 才有的
`.onChange(of:initial:)`。这个重建版从功能描述出发重写，**完全不用**
这两个调用（详见 `IOS16-COMPLIANCE.md`），相册选择用 `matching: nil`
再按类型过滤。

功能（按原项目公开说明）：相册图片 / 视频、摄像头、CarPlay 视频流
（OXP `/oxp/v0`，仅画面）、测试图、五寸 848×480 H.264/RTP 与
4.3 寸 480×272 JPEG/RTP 两种仪表预设、画面设置（完整 / 裁满 / 拉伸）、
诊断日志、App 内检查更新。七寸 KCP 在 iOS 上不支持，本版不提供。

## 没有包含的东西（请先看）

- **没有预编译的 IPA，也没有在这台机器上编译 / 真机测试过。**
  这里是 Linux 虚拟机，没有 Mac、没有 Xcode、没有 Swift 编译器，
  所以无法本地构建。请用下面方法一（推荐，无需 Mac）或方法二
  （有 Mac）在苹果的工具链上构建。
- 没有原 1.0.1 的任何代码（仓库里本来也没有源码可抄）。
- 图标是占位图（蓝色底 + 白色 NP），发布前请换成正式图标。

---

## 方法一（推荐）：没有 Mac — 用 GitHub Actions 云端构建

你只需要一个 GitHub 账号和浏览器，**不需要 Mac、不需要证书、不需要
任何密钥**。构建在 GitHub 的 macOS  runner 上跑。

### 1. 把项目推到 GitHub

在 GitHub 上新建一个仓库（公开仓库最好，见费用说明），然后把整个
`ios16-rebuild` 文件夹的内容推上去：

```bash
cd ios16-rebuild
git init
git add .
git commit -m "Ninebot Pro clean-room rebuild 1.1.0 for iOS 16"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

仓库里已有 `.github/workflows/build-ios.yml`，push 后会自动触发构建。

### 2. 等构建完成

打开仓库的 **Actions** 标签页 → 点 `Build iOS (unsigned IPA)` 那次运行 →
等它变绿（通常几分钟）。也可以点 **Run workflow** 手动再跑一次。

工作流做的事情（都在 `.github/workflows/build-ios.yml` 里，可直接看）：
在 `macos-14` 上选 Xcode 15.4（能 targeting iOS 16.0，不要用 Xcode 26），
跑 `xcodebuild -scheme NinebotPro -configuration Release
-destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`，
核对产物 `Info.plist` 的 `MinimumOSVersion` 是 16.0，
再把 `.app` 装进 `Payload/` 打包成未签名 IPA
`ninebot-pro-ios16-rebuild-unsigned.ipa`，算 SHA-256，上传为 artifact。

### 3. 下载 IPA

在那次成功的运行页面底部 **Artifacts** 里下载
`ninebot-pro-ios16-rebuild-unsigned-ipa`，解压得到
`ninebot-pro-ios16-rebuild-unsigned.ipa` 和 `SHA256SUMS.txt`。
核对 SHA-256 和文件里的一致。

### 4. 自行签名并安装到 iOS 16.4.1 手机

这个 IPA 和原 1.0.1 一样是**未签名**的，不能直接安装，要用你自己的
Apple ID / 证书自签，流程和原版完全一样。任选其一：

- **AltStore（Windows）**：电脑装 AltServer + iTunes（苹果官网版），
  手机装 AltStore，用自己的免费 Apple ID 签名安装。免费证书有效期
  7 天，到期需在同一 Wi-Fi 下刷新；免费账号最多同时装 3 个自签应用。
- **Sideloadly（Windows / Mac）**：类似，用自己的 Apple ID 签名安装，
  同样是 7 天免费证书。
- **ESign（手机上直接签）**：用你自己的证书（.p12 + 描述文件）导入
  ESign 后签名安装。请只用你自己的证书，不要用网上来路不明的证书。

装好后先按下面“真机测试清单”逐项测，确认能打开、能投屏。

### 费用

GitHub Actions 对**公开仓库免费**（构建分钟数不限）。私有仓库每月有
2,000 分钟免费额度，macOS  runner 按 10 倍计费，一次约几分钟的构建
大约消耗几十分钟额度，通常也在免费额度内。工作流本身不产生其他费用。

---

## 方法二（备选）：有 Mac — 本地用 Xcode 构建

1. 用 Xcode 15.4 或更高版本打开 `NinebotPro/NinebotPro.xcodeproj`
   （不要用 Xcode 26；原崩溃就是新 SDK 链接的符号在 iOS 16 上不存在）。
2. 在 Target → Signing & Capabilities 里选你自己的 Team，Bundle ID
   保持 `com.hanlin.ninebotpro`（改了 Bundle ID 会影响 App 内更新匹配）。
3. 选一台真机或 `Any iOS Device`，Product → Archive；或命令行：

```bash
cd ios16-rebuild
xcodebuild -project NinebotPro/NinebotPro.xcodeproj \
  -scheme NinebotPro -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

未签名 IPA 打包（命令行，产物在
`build/DerivedData/Build/Products/Release-iphoneos/NinebotPro.app`）：

```bash
APP="build/DerivedData/Build/Products/Release-iphoneos/NinebotPro.app"
mkdir -p Payload && cp -R "$APP" Payload/
zip -r -y ninebot-pro-ios16-rebuild-unsigned.ipa Payload
shasum -a 256 ninebot-pro-ios16-rebuild-unsigned.ipa
```

核对产物 `Info.plist` 里 `MinimumOSVersion` 为 `16.0`、
`CFBundleShortVersionString` 为 `1.1.0` 后再签名安装。

---

## 项目结构

```
ios16-rebuild/
├── README-BUILD.md                  本文件
├── IOS16-COMPLIANCE.md              iOS 16 合规检查（禁用的 API 清单）
├── gen_pbxproj.py                   重新生成 project.pbxproj 的脚本
├── .github/workflows/build-ios.yml  GitHub Actions 云端构建（方法一）
└── NinebotPro/
    ├── NinebotPro.xcodeproj/project.pbxproj
    ├── NinebotPro/
    │   ├── NinebotProApp.swift      @main 入口，@StateObject
    │   ├── Info.plist              MinimumOSVersion 16.0
    │   ├── Assets.xcassets/        AppIcon 占位图 + AccentColor
    │   ├── Models/                 DashboardPreset / CastSource /
    │   │                           CropMode / AppLogStore / AppState
    │   ├── Transport/              UDPSender（UDP 5012/5013）/
    │   │                           H264Encoder（VideoToolbox）/
    │   │                           RTPPacketizer（RTP/FU-A）/
    │   │                           JPEGFramePacketizer / FrameScaler
    │   ├── Sources/                PhotoVideoSource（matching: nil）/
    │   │                           CameraSource / TestImageSource /
    │   │                           CarPlaySource（OXP /oxp/v0）
    │   ├── Services/               MirrorSession / UpdateChecker
    │   └── Views/                  Home / Settings / CarPlay /
    │                               About / Diagnostics
    └── .gitignore
```

## 真机测试清单（iOS 16.4.1，iPhone 14 Pro Max）

按顺序测，任何一步闪退都把 `.ips` 崩溃日志发回来，dyld 会报下一个
缺失的符号：

1. [ ] 启动：点开 App 不闪退，进到首页。
2. [ ] 连接：仪表开启投屏，手机连上仪表 Wi-Fi，App 里填好仪表地址。
3. [ ] 测试图：诊断页“投送测试图”，仪表有画面。
4. [ ] 相册图片：选一张图片投屏，仪表有画面。
5. [ ] 相册视频：选一段视频投屏，画面连续、声音在手机播放。
6. [ ] 摄像头：摄像头投屏，画面实时；按 Home 键回后台再回来，恢复正常。
7. [ ] CarPlay（若有兼容接收应用）：填好服务地址和端口，画面出现。
8. [ ] 更新检查：关于页“检查更新”，无网络时不崩溃、有提示。

## 已知限制

- 七寸仪表（1024×600，KCP）在 iOS 上不支持，本版不提供七寸预设。
- 手机屏幕跨 App 录制不支持（原 iOS 版同样不支持）。
- CarPlay 只投画面，不传声音和触控；接收应用必须提供兼容 OXP 接口，
  CarWithin、CarCast 尚未列为已验证支持。
- 视频声音在手机播放，不经过仪表。
- 摄像头需在前台使用；进入后台暂停采集、保留最后画面。
- App 内更新检查读取原 1.0.1 的 `ios-update.json`（1.0.1，构建 2），
  本版 1.1.0 构建 1 比它新，正常会显示“已是最新版”；发布新版时请为
  重建版单独发布一份更新文件。
- 相册视频通过 `loadTransferable(type: Data.self)` 整段加载后再转码，
  很长的视频会占用较多内存和时间，属已知取舍。
