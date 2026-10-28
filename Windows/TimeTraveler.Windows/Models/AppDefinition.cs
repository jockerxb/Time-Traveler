namespace TimeTraveler.Windows.Models;

public sealed record AppDefinition(
    string Id,
    string ChineseName,
    string EnglishName,
    string[] ExecutableNames,
    string[] ProcessNames,
    string[] CandidatePaths,
    string[] ShortcutNames,
    string[] UriSchemes,
    string AccentHex,
    int WarmupSeconds)
{
    public string DisplayName(AppLanguage language) =>
        language == AppLanguage.Chinese ? ChineseName : EnglishName;
}

public static class AppCatalog
{
    public static IReadOnlyList<AppDefinition> All { get; } =
    [
        new(
            "feishu",
            "飞书",
            "Feishu",
            ["Feishu.exe", "Lark.exe"],
            ["Feishu", "Lark"],
            [
                @"%LOCALAPPDATA%\Feishu\Feishu.exe",
                @"%LOCALAPPDATA%\Lark\Lark.exe",
                @"%PROGRAMFILES%\Feishu\Feishu.exe",
                @"%PROGRAMFILES%\Lark\Lark.exe",
                @"%PROGRAMFILES(X86)%\Feishu\Feishu.exe",
                @"%PROGRAMFILES(X86)%\Lark\Lark.exe"
            ],
            ["飞书", "Feishu", "Lark"],
            ["feishu:", "lark:"],
            "#3370FF",
            45),
        new(
            "wechat",
            "微信",
            "WeChat",
            ["WeChat.exe", "Weixin.exe"],
            ["WeChat", "Weixin"],
            [
                @"%PROGRAMFILES%\Tencent\WeChat\WeChat.exe",
                @"%PROGRAMFILES(X86)%\Tencent\WeChat\WeChat.exe",
                @"%PROGRAMFILES%\Tencent\Weixin\Weixin.exe",
                @"%PROGRAMFILES(X86)%\Tencent\Weixin\Weixin.exe",
                @"%LOCALAPPDATA%\Tencent\WeChat\WeChat.exe",
                @"%LOCALAPPDATA%\Tencent\Weixin\Weixin.exe",
                @"%LOCALAPPDATA%\WeChat\WeChat.exe"
            ],
            ["微信", "WeChat", "Weixin"],
            ["weixin:", "wechat:"],
            "#07C160",
            20),
        new(
            "whatsapp",
            "WhatsApp",
            "WhatsApp",
            ["WhatsApp.exe"],
            ["WhatsApp"],
            [
                @"%LOCALAPPDATA%\WhatsApp\WhatsApp.exe",
                @"%PROGRAMFILES%\WhatsApp\WhatsApp.exe",
                @"%PROGRAMFILES(X86)%\WhatsApp\WhatsApp.exe"
            ],
            ["WhatsApp"],
            ["whatsapp:"],
            "#25D366",
            15),
        new(
            "telegram",
            "Telegram",
            "Telegram",
            ["Telegram.exe"],
            ["Telegram"],
            [
                @"%APPDATA%\Telegram Desktop\Telegram.exe",
                @"%LOCALAPPDATA%\Telegram Desktop\Telegram.exe",
                @"%PROGRAMFILES%\Telegram Desktop\Telegram.exe",
                @"%PROGRAMFILES(X86)%\Telegram Desktop\Telegram.exe"
            ],
            ["Telegram"],
            ["tg:"],
            "#229ED9",
            12)
    ];
}
