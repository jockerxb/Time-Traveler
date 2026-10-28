# Time Traveler for Windows（预览版）

Windows 版解决同一个问题：系统切换到其他地区的时区后，飞书、微信、WhatsApp 和 Telegram 仍可按你选择的时区启动。

## 使用

1. 下载与电脑架构匹配的 portable ZIP（多数 Windows 电脑选择 `x64`）。
2. 解压后运行 `TimeTraveler.exe`。
3. 选择启动时区，然后点击应用图标。
4. Windows 询问管理员权限时选择“是”。Time Traveler 会短暂切换系统时区，目标应用启动后自动恢复。

如果未安装目标应用，界面会明确提示安装后再试。Time Traveler 只在本机运行，不读取或上传聊天内容和个人数据，也不会修改目标应用文件。

请保留同一目录中的 `TimeTraveler.Helper.exe`；它是独立的恢复守护程序，负责在主程序异常退出时恢复原系统时区。

> 这是预览版。自动化测试覆盖应用发现、时区切换、目标进程继承和系统时区恢复；四款真实客户端仍需在实际 Windows 电脑上完成验收。

## Build and test

Requires the .NET 8 SDK on Windows.

```powershell
dotnet run --project Windows/TimeTraveler.SmokeTests/TimeTraveler.SmokeTests.csproj -c Release
powershell -ExecutionPolicy Bypass -File Windows/scripts/build.ps1
```

GitHub Actions additionally runs an end-to-end probe that changes the runner time zone, launches a child process, and verifies that the original time zone is restored.
