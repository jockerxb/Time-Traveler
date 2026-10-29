# Time Traveler for Windows（预览版）

**中文** · [English](README_EN.md)

Windows 版解决同一个问题：系统切换到其他地区的时区后，飞书、微信、WhatsApp 和 Telegram 仍可按你选择的时区启动。

## 使用

1. 下载与电脑架构匹配的 portable ZIP（多数 Windows 电脑选择 `x64`）。
2. 完整解压后运行 `TimeTraveler.exe`，无需另装 .NET。
3. 选择启动时区，然后点击应用图标。
4. Windows 询问管理员权限时选择“是”。Time Traveler 会短暂切换系统时区，目标应用启动后自动恢复。

如果未安装目标应用，界面会明确提示安装后再试。Time Traveler 只在本机运行，不读取或上传聊天内容和个人数据，也不会修改目标应用文件。

请保留同一目录中的 `TimeTraveler.Helper.exe`；它是独立的恢复守护程序，负责在主程序异常退出时恢复原系统时区。

> 这是预览版。自动化测试验证 Windows 时区切换、子进程启动、启动失败恢复和主进程消失后的恢复。四款真实客户端的消息与日历显示仍需在实际 Windows 电脑上验收；客户端可能在系统时区恢复后重新读取时区。

## Build and test

Requires the .NET 8 SDK on Windows.

```powershell
dotnet run --project Windows/TimeTraveler.SmokeTests/TimeTraveler.SmokeTests.csproj -c Release
pwsh -File Windows/scripts/build.ps1
```

GitHub Actions additionally runs an end-to-end probe that changes the runner time zone, launches a child process, and verifies that the original time zone is restored.

安装包尚未签名。如被 Windows 拦截，请先确认文件来自本仓库，再决定是否运行；无需关闭系统安全防护。
