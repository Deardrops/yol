# Yol Wallpaper

<p align="center">
  <img src="assets/tray_icon.png" alt="Yol Wallpaper Icon" width="96" />
</p>

<p align="center">
  Automatically refresh your desktop with stunning landscape wallpapers from Reddit's r/EarthPorn.
</p>

<p align="center">
  <a href="#Overview">English</a> · <a href="./README.zh.md">中文</a>
</p>

---

### Overview

**Yol Wallpaper** is a cross-platform Flutter application that automatically fetches high-quality landscape photos from Reddit's [r/EarthPorn](https://www.reddit.com/r/EarthPorn/) subreddit and sets them as your device wallpaper. Browse curated images, set your favorite manually, or let the app refresh your wallpaper once a day, automatically.

### Features

- **Automatic daily wallpaper** — Updates once per day in the background; no manual action required.
- **Browse before you set** — Swipe through today's top landscape images with smooth slide transitions before choosing one.
- **High-quality only** — Filters images to a minimum width of 2,500 px for crisp, full-resolution wallpapers.
- **System tray integration** *(Windows / macOS)* — Lives quietly in the system tray with a right-click context menu.
- **Cross-platform** — Android, Windows, macOS, and more.

### Supported Platforms

| Platform | Background Auto-update      | System Tray |
|----------|-----------------------------|-------------|
| Android  | ✅ WorkManager               | —           |
| Windows  | ✅ Timer-based               | ✅           |
| macOS    | ✅ Timer-based               | ✅           |
| iOS      | ⚠️ Limited (OS restrictions) | —           |
| Linux    | 🔧 Experimental              | —           |

### Installation

#### Pre-built Binaries

Download the latest release from the [Releases](../../releases) page:

| Platform | File                  |
|----------|-----------------------|
| Windows  | `yol_app_windows.zip` |
| macOS    | `yol_app_macos.zip`   |
| Android  | `app-release.apk`     |

> **macOS note:** The binary is unsigned. To run it, remove the quarantine attribute:
> ```bash
> xattr -cr /Applications/yol_app.app
> ```

#### Build from Source

**Prerequisites:** Flutter SDK ≥ 3.x, Dart SDK ≥ 3.11

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

### Usage

1. Launch the app — it fetches today's top landscape images automatically.
2. Tap **←** / **→** to browse available wallpapers.
3. Tap **Set as Wallpaper** to apply the current image.
4. The app will check once a day (at startup or via background task) and auto-update your wallpaper.

On **Windows / macOS**, minimize the app window — it stays accessible from the system tray.

### How It Works

```
App Start / Background Task
        │
        ▼
  Fetch top posts from r/EarthPorn (Reddit JSON API)
        │
        ▼
  Filter: image posts, JPG/PNG, width ≥ 2500 px
        │
        ▼
  Display previews  ──── User picks ────► Set wallpaper
        │
        ▼ (auto mode)
  Set top wallpaper & save date to SharedPreferences
```

### Project Structure

```
lib/
├── main.dart                  # Entry point & WorkManager registration
├── background/
│   └── background_task.dart   # Android background callback
├── models/
│   └── wallpaper_post.dart    # Data model
├── services/
│   ├── reddit_service.dart    # Reddit API client
│   ├── wallpaper_service.dart # Cross-platform wallpaper setter
│   └── storage_service.dart   # SharedPreferences wrapper
├── ui/
│   ├── home_screen.dart       # Main screen
│   └── tray_setup.dart        # Windows/macOS tray integration
└── utils/
    └── proxy_overrides.dart   # System proxy support
```

### Contributing

Contributions are welcome! Please open an issue to discuss what you'd like to change before submitting a pull request.

1. Fork the repository.
2. Create a feature branch: `git checkout -b feat/your-feature`.
3. Commit your changes: `git commit -m 'feat: add your feature'`.
4. Push and open a Pull Request.

### License

This project is licensed under the [MIT License](LICENSE).
