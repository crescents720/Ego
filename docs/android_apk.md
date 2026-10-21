# Android 手机测试包 · 2026-10-18

安装包：`builds/android/FireflyRoad-0.1.20261018.2-arm64-debug.apk`，约 208 MB（约 198.5 MiB）。应用名“末日与黎明”，包名 `com.fireflyroad.dawn`，版本 `0.1.20261018.2` / code 2。使用本机 Godot 的调试签名，适合直接安装测试。

最新版封面、图标、双指摇杆和便利店出口修复见 [第二版记录](mobile_controls_store_fix.md)。

## 手机上安装

1. 将 APK 文件通过 USB 或文件传输工具复制到安卓手机。
2. 在手机的文件管理器中打开 APK；如提示，允许该文件管理器“安装未知应用”，然后安装。
3. 打开“末日与黎明”，点击“新游戏”。拖动左下摇杆移动，右下按钮执行上车、攻击等操作。

本包仅含 ARM64，最低 Android API 24，当前 Mobile 渲染器需要 Vulkan。保留现有画质及游戏规则，手机性能需要真机实测。首次启动会加载资源及着色器，请等待。较长比例的手机屏幕会保留上下黑边以保持 9:16 游戏画面。

电脑存档不会自动同步到手机。同包名、同签名的后续 APK 可覆盖安装并保留手机存档；不要为更新随意卸载应用。

## 电脑环境

- Godot 4.6.3：`C:/Users/ding5/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`。
- Android Studio 自带 Java：`C:/Program Files/Android/Android Studio/jbr`（本机 JBR 25，实际导出和签名验证成功）。
- SDK：`C:/Users/ding5/AppData/Local/Android/Sdk`，Build Tools 36.0.0，platform-tools adb。
- Godot 编辑器全局 SDK/Java 路径已配置；配置前备份在 `artifacts/android_export_setup/`。
- Android 纹理导入已开启 `textures/vram_compression/import_etc2_astc=true`。只启用移动平台所需的额外纹理导入，保留 Mobile 渲染器。

特别注意：本机全局 `export_templates/4.6.3.stable` 目录中的旧模板实际为 **4.6.stable**，不能依赖目录名判断版本。本项目 Android debug 预设已指定官方 4.6.3 自定义模板：`source/export_templates/4.6.3/android_debug.apk`，源目录不会被打进游戏包。

官方模板来自 [Godot 4.6.3 发布页](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable)，从官方模板 ZIP 中按范围下载 Android debug 成员，并验证成员长度和 ZIP CRC。其 SHA256：`5cd4cfc1a8fc23ed45be5f0a36a6cc279d15b50a40c6ef69c89276895441cd1d`。Android Manifest 内部版本与运行日志均确认是 `4.6.3.stable`。当前仅配置并验证 debug 导出，正式发布签名及 release 模板另行配置。

## 重复导出

在项目根目录运行 `powershell -ExecutionPolicy Bypass -File tools/export_android.ps1`。脚本会先导入资源，再输出预设中的签名测试 APK；不读取或改动玩家存档。也可以在 Godot 的项目导出窗口选择 Android、勾选调试导出。

`export_presets.cfg` 排除测试工具、截图、文档、源模型及构建目录，显式带入 `licenses/*.txt`。应用不申请联网、相机、录音和存储等权限。精确 APK 字节数、SHA256、架构和包含的许可文件见同目录 `build_info-revision2.json`。

## 已验证和范围

- Godot 命令行导出成功，APK v2/v3 签名及 16 KB ZIP 对齐验证通过。
- 在 Android Studio 的 Android API 37 模拟器安装成功，Launcher 能解析，官方 ARM64 模板通过模拟器原生转译启动，Vulkan Mobile 渲染正常。
- 实际查看中文标题、新游戏、游戏内人物/丧尸/火焰/小地图和死亡界面。安装包内动态加载资源正常；运行阶段未出现脚本或资源缺失错误。
- 场景重载时发现的 AudioDirector 旧场景节点访问已修复，`tools/verify_audio_lifecycle.gd` 验证通过。最终 APK 点击重新开始已返回标题；重载日志仍出现一条无脚本调用栈的引擎 `can_process` 节点离树提示，没有导致崩溃或阻止返回标题，留待后续排查。
- 截图及 Android 运行日志存放在 `artifacts/android_export_setup/`。模拟器测试用于安装和功能检查，不能代表手机帧率、续航、温度或声音听感；尚未连接真实手机测试。

导出流程参考 [Godot Android 官方导出说明](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)。本次使用非 Gradle 模板导出，现有 SDK 即可完成，不需要额外下载 NDK/CMake 或建立 Android Studio 工程。


## 2026-10-19 第六版

当前导出：builds/android/FireflyRoad-0.1.20261019.6-arm64-debug.apk，242717713字节，versionCode6，包名com.fireflyroad.dawn。沿用第五版debug签名，可覆盖安装保留存档。整合工厂原模型内室、铁丝闪光、推车进出及留车修复、车床人工加工/下车安装、四侧围栏防护及修复、通用窗口名称和管理菜单修正。签名v2/v3、16KB zipalign、ZIP CRC通过；精确哈希与验证记录见build_info-revision6.json。
