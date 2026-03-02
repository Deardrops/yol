
# Yol Wallpaper

<p align="center">
  <img src="assets/tray_icon.png" alt="Yol Wallpaper Icon" width="96" />
</p>

<p align="center">
  自动从 Reddit r/EarthPorn 获取绝美风景壁纸，每日更新桌面。
</p>

<p align="center">
  <a href="./README.md">English</a> · <a href="./README.zh.md">中文</a>
</p>

---

### 简介

**Yol Wallpaper** 是一款跨平台 Flutter 应用，自动从 Reddit 的 [r/EarthPorn](https://www.reddit.com/r/EarthPorn/) 板块获取高质量风景照片，并将其设置为设备壁纸。你可以在设置前预览当日精选图片，也可以开启每日自动更新，让壁纸每天焕然一新。

### 功能特性

- **每日自动换壁纸** — 后台每日更新一次，无需手动操作。
- **设置前可预览** — 左右切换今日精选风景图，满意后再一键设置。
- **方向感知过滤** — 横屏设备（Windows / macOS）仅拉取横版壁纸，竖屏设备（Android）仅拉取竖版壁纸，方向完全匹配。
- **预览与填充效果一致** — 应用窗口比例与屏幕比例相同，预览图以**填充**模式裁切显示，与最终壁纸效果完全一致，所见即所得。
- **系统托盘集成** *(Windows / macOS)* — 静默驻留系统托盘，右键即可快速操作。
- **跨平台支持** — 支持 Android、Windows、macOS 等多个平台。

### 平台支持

| 平台     | 后台自动更新            | 系统托盘 |
|----------|-------------------------|----------|
| Android  | ✅ WorkManager           | —        |
| Windows  | ✅ 定时器方案            | ✅        |
| macOS    | ✅ 定时器方案            | ✅        |
| iOS      | ⚠️ 受系统限制，功能受限  | —        |
| Linux    | 🔧 实验性支持            | —        |

### 安装

#### 下载预构建包

前往 [Releases](../../releases) 页面下载最新版本：

| 平台    | 文件                  |
|---------|-----------------------|
| Windows | `yol_app_windows.zip` |
| macOS   | `yol_app_macos.zip`   |
| Android | `app-release.apk`     |

> **macOS 用户注意：** 安装包未经过签名，首次运行前请执行以下命令移除隔离属性：
> ```bash
> xattr -cr /Applications/yol_app.app
> ```

#### 从源码构建

**前置条件：** Flutter SDK ≥ 3.x，Dart SDK ≥ 3.11

```bash
git clone https://github.com/<your-username>/yol_app.git
cd yol_app
flutter pub get

# Android
flutter build apk --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

### 使用方法

1. 启动应用 — 自动获取今日与设备屏幕方向匹配的精选风景图。
2. 点击 **←** / **→** 切换浏览可用壁纸。
3. 点击 **设置为壁纸** 将当前图片应用为壁纸（填充模式）。
4. 应用每天会在启动时或后台任务中自动检测并更新壁纸（每日一次）。

在 **Windows / macOS** 上最小化窗口后，应用将继续在系统托盘运行，右键托盘图标可快速访问。

### 工作原理

```
应用启动 / 后台任务
        │
        ▼
  从 r/EarthPorn 获取热门帖子（Reddit JSON API）
        │
        ▼
  筛选：图片帖子（JPG/PNG）且方向与设备屏幕一致
  （横屏设备拉取宽 ≥ 高的图片，竖屏设备拉取高 > 宽的图片）
        │
        ▼
  展示预览（窗口与屏幕同比例，填充裁切，所见即所得）
        │
        ├── 用户手动选择 ────► 设置壁纸（填充模式）
        │
        ▼ （自动模式）
  设置最高热度壁纸，并将日期保存至 SharedPreferences
```

### 项目结构

```
lib/
├── main.dart                  # 入口、WorkManager 注册 & 窗口尺寸初始化
├── background/
│   └── background_task.dart   # Android 后台回调
├── models/
│   └── wallpaper_post.dart    # 数据模型（含图片尺寸与方向属性）
├── services/
│   ├── reddit_service.dart    # Reddit API 客户端（含方向过滤）
│   ├── wallpaper_service.dart # 跨平台壁纸设置
│   └── storage_service.dart   # SharedPreferences 封装
├── ui/
│   ├── home_screen.dart       # 主界面（填充预览）
│   └── tray_setup.dart        # Windows/macOS 托盘集成
└── utils/
    └── proxy_overrides.dart   # 系统代理支持
```

### 参与贡献

欢迎提交 Issue 或 Pull Request！在提交 PR 之前，请先开 Issue 说明你想改动的内容。

1. Fork 本仓库。
2. 创建功能分支：`git checkout -b feat/your-feature`。
3. 提交更改：`git commit -m 'feat: 描述你的改动'`。
4. 推送并发起 Pull Request。

### 开源协议

本项目采用 [MIT 许可证](LICENSE)。
