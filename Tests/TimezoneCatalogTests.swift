import Foundation

@main
enum TimezoneCatalogTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_788_192_000)
        let beijing = ZoneCatalog.search("北京", at: now)
        precondition(beijing.contains { $0.rawValue == "Asia/Shanghai" }, "北京搜索必须包含 Asia/Shanghai")

        let losAngeles = ZoneCatalog.search("Los Angeles", at: now)
        precondition(losAngeles.contains { $0.rawValue == "America/Los_Angeles" }, "英文城市搜索必须找到洛杉矶")

        let shanghai = Destination(rawValue: "Asia/Shanghai")!
        precondition(shanghai.displayCity(in: .chinese) == "北京 / 上海", "中文界面必须显示北京 / 上海")
        precondition(shanghai.displayCity(in: .english) == "Beijing / Shanghai", "英文界面必须显示 Beijing / Shanghai")
        precondition(AppText(language: .english).notInstalled == "Not installed", "英文界面文案必须可用")

        let utcEight = ZoneCatalog.search("utc8", at: now)
        precondition(utcEight.contains { $0.rawValue == "Asia/Shanghai" }, "UTC+8 搜索必须包含北京/上海")

        precondition(ZoneCatalog.search("utc99", at: now).isEmpty, "非法 UTC 偏移必须为空")
        precondition(Destination(rawValue: "not/a-zone") == nil, "非法 IANA 时区必须被拒绝")
        print("PASS 时区搜索、多语言、UTC 偏移与 IANA 校验")
    }
}
