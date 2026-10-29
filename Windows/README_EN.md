# Time Traveler for Windows (Preview)

Choose a launch time zone for Feishu, WeChat, WhatsApp, or Telegram while keeping your usual Windows time zone after launch.

## Use

1. Download the portable ZIP for your PC: `x64` for most Intel/AMD PCs, or `ARM64` for Windows on Arm.
2. Extract the entire ZIP, then run `TimeTraveler.exe`. No separate .NET installation is needed.
3. Choose a time zone, then click an app icon. Use the language button to switch between Chinese and English.
4. Allow the Windows administrator prompt. The launcher briefly changes the system time zone while the app starts, then restores it automatically.

Keep `TimeTraveler.Helper.exe` next to the main app. It restores the original time zone even if the launcher closes unexpectedly. Missing apps prompt you to install them first.

Time Traveler runs locally, does not read or upload chats or personal data, and does not modify client files.

> This is a preview. Automated tests verify Windows time-zone switching, child-process launch, restoration after launch failure, and recovery when the parent process disappears. Message and calendar display in the four real clients still needs acceptance testing on a Windows PC. A client may refresh its time zone after the system time zone is restored.

## Build

Requires the .NET 8 SDK on Windows:

```powershell
dotnet run --project Windows/TimeTraveler.SmokeTests/TimeTraveler.SmokeTests.csproj -c Release
pwsh -File Windows/scripts/build.ps1
```

Packages are unsigned. If Windows blocks the download, check that it came from this repository before deciding whether to run it. Do not disable Windows security protections.
