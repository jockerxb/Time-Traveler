# Time Traveler

让聊天软件按指定时区启动，不受当前系统时区影响。

## 使用

1. 打开 **Time Traveler**。
2. 选择启动时区；首次使用默认为空。
3. 点击飞书、微信、WhatsApp 或 Telegram 图标启动。

选择会保存在本机；右键时区卡片可以清除当前选择。若目标应用正在运行，Time Traveler 会先询问是否退出并重新启动。

> 飞书日历只在冷启动时读取完整时区。启动飞书时，Time Traveler 会短暂切换系统时区并自动恢复，因此需要 macOS 管理员授权。

## 构建

需要 macOS 13 或以上以及 Xcode Command Line Tools。

```sh
./test.sh
./build.sh
```

构建产物位于 `dist/Time Traveler.app`。
