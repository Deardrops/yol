#include "flutter_window.h"

#include <optional>
#include <string>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Register the wallpaper method channel.
  // wallpaper_channel_ is a shared_ptr member so it outlives OnCreate().
  wallpaper_channel_ =
      std::make_shared<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.example.yol_app/wallpaper",
          &flutter::StandardMethodCodec::GetInstance());

  wallpaper_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "setWallpaper") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("path"));
            if (it != args->end()) {
              const std::string& utf8_path =
                  std::get<std::string>(it->second);
              int wide_len = ::MultiByteToWideChar(
                  CP_UTF8, 0, utf8_path.c_str(), -1, nullptr, 0);
              std::wstring wide_path(wide_len, L'\0');
              ::MultiByteToWideChar(CP_UTF8, 0, utf8_path.c_str(), -1,
                                    &wide_path[0], wide_len);

              // Set fill mode in the registry before applying the wallpaper.
              // WallpaperStyle values: 0=Center 2=Stretch 6=Fit 10=Fill 22=Span
              auto writeRegStr = [](const wchar_t* name, const wchar_t* value) {
                HKEY hKey;
                if (::RegOpenKeyExW(HKEY_CURRENT_USER,
                                    L"Control Panel\\Desktop",
                                    0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
                  ::RegSetValueExW(hKey, name, 0, REG_SZ,
                                   reinterpret_cast<const BYTE*>(value),
                                   static_cast<DWORD>(
                                       (wcslen(value) + 1) * sizeof(wchar_t)));
                  ::RegCloseKey(hKey);
                }
              };
              writeRegStr(L"WallpaperStyle", L"10");
              writeRegStr(L"TileWallpaper",  L"0");

              BOOL ok = ::SystemParametersInfoW(
                  SPI_SETDESKWALLPAPER, 0,
                  static_cast<PVOID>(
                      const_cast<LPWSTR>(wide_path.c_str())),
                  SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);

              if (ok) {
                result->Success(flutter::EncodableValue(true));
              } else {
                DWORD err = ::GetLastError();
                result->Error("SET_FAILED",
                              "SystemParametersInfoW returned FALSE",
                              flutter::EncodableValue(
                                  static_cast<int32_t>(err)));
              }
              return;
            }
          }
          result->Error("BAD_ARGS", "Expected {path: String}",
                        flutter::EncodableValue());
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
