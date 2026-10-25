# Time Traveler

**系统时区属于电脑，聊天时间由你选择。**

Time Traveler 是一款开源的 macOS 时区启动器。即使系统切换到其他国家或地区的时区，也可以让常用聊天软件按你选择的时区启动，避免消息时间、日历时间和工作安排混乱。

[下载最新版本](https://github.com/jockerxb/Time-Traveler/releases/latest) · [查看源代码](https://github.com/jockerxb/Time-Traveler)

## 应用场景

当你修改 Mac 系统时区后，仍希望飞书、微信等 IM 软件保留其常用所在地时区，避免消息和日历时间随系统一起变化。

## 基础功能

- 为 **飞书、微信、WhatsApp 和 Telegram** 单独选择启动时区，系统时区保持原设置或在启动后自动恢复。
- 本地运行、开源透明，不上传聊天内容和个人数据。
- 不注入进程、不修改客户端、不模拟账号行为，不属于外挂，不会因外挂行为触发封禁；账号安全仍以各软件最新规则为准。

## 适配系统

| 项目 | 支持范围 |
| --- | --- |
| macOS | macOS 13 Ventura 或更高版本 |
| Mac 芯片 | Apple Silicon 与 Intel |
| 聊天软件 | 飞书、微信、WhatsApp、Telegram |

### 从源码构建

需要安装 Xcode Command Line Tools：

```sh
./test.sh
./build.sh universal
```

构建结果位于 `dist/Time Traveler.app`。

> [!IMPORTANT]
> ### 首次打开提示“无法验证开发者”
>
> 当前公开版本未经过 Apple notarization。首次打开时，请在 Finder 中找到 **Time Traveler.app**，右键选择 **打开**，再确认一次 **打开**。
>
> 如果仍被拦截，请进入 **系统设置 → 隐私与安全性**，在安全性区域点击 **仍要打开**。无需关闭 Gatekeeper，也不要修改系统整体安全策略。

## 支持 Time Traveler

如果 Time Traveler 解决了你的时区问题，欢迎点击 GitHub 页面右上角的 **⭐ Star**，让更多有同样需求的人看到它。

[⭐ 在 GitHub 为 Time Traveler 加 Star](https://github.com/jockerxb/Time-Traveler)
