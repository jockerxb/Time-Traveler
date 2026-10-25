# Time Traveler

**系统时区属于电脑，聊天时间由你选择。**

Time Traveler 是一款开源的 macOS 时区启动器。即使系统切换到其他国家或地区的时区，也可以让常用聊天软件按你选择的时区启动，避免消息时间、日历时间和工作安排混乱。

[下载最新版本](https://github.com/jockerxb/Time-Traveler/releases/latest) · [查看源代码](https://github.com/jockerxb/Time-Traveler)

## 应用场景

- **跨时区生活与工作**：系统使用所在地时区，飞书和微信继续使用国内团队的时间。
- **海外出差或远程协作**：不用反复修改整台 Mac 的时区，也能按客户或团队时区查看消息。
- **时区测试**：为聊天软件单独选择时区，快速检查不同地区下的时间显示。

## 基础功能

- 一个入口启动 **飞书、微信、WhatsApp 和 Telegram**。
- 按城市或 UTC 偏移搜索全球时区，选择结果自动保存在本机。
- 点击应用图标即可按目标时区启动；若应用已运行，会先提示确认后再重新启动。
- 左键时区卡片可更换时区，右键可清除当前选择。
- 针对飞书日历的冷启动机制，临时切换系统时区完成启动后自动恢复，不长期改变系统设置。
- 本地运行、开源透明，不上传聊天内容和个人数据。

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
