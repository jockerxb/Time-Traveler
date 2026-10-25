import Foundation

struct Destination: Hashable, Identifiable {
    let rawValue: String
    var id: String { rawValue }

    private static let allowed: Set<String> = {
        let tableIDs = ["zone.tab", "zone1970.tab"].flatMap { filename -> [String] in
            guard let table = try? String(contentsOfFile: "/usr/share/zoneinfo/" + filename, encoding: .utf8) else { return [] }
            return table.split(separator: "\n").compactMap { line in
                guard !line.hasPrefix("#") else { return nil }
                let fields = line.split(separator: "\t")
                return fields.count >= 3 ? String(fields[2]) : nil
            }
        }
        return Set(TimeZone.knownTimeZoneIdentifiers + tableIDs + ["Etc/UTC", "UTC"])
            .filter { TimeZone(identifier: $0) != nil && FileManager.default.fileExists(atPath: "/usr/share/zoneinfo/" + $0) }
    }()

    init?(rawValue: String) {
        guard Self.allowed.contains(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    static let allCases = allowed.sorted().compactMap(Destination.init(rawValue:))
    var zone: TimeZone { TimeZone(identifier: rawValue)! }
    var city: String { ZoneCatalog.labels[rawValue]?.city ?? rawValue }
    var englishCity: String { ZoneCatalog.labels[rawValue]?.english ?? rawValue }
    func displayCity(in language: AppLanguage) -> String { language == .chinese ? city : englishCity }
    private var ruleData: Data? { try? Data(contentsOf: URL(fileURLWithPath: "/usr/share/zoneinfo/" + rawValue)) }
    var catalogID: String { ZoneCatalog.representatives[rawValue] ?? rawValue }

    func isSameLocation(as other: Destination) -> Bool { catalogID == other.catalogID }

    func offset(at date: Date) -> String {
        let minutes = zone.secondsFromGMT(for: date) / 60
        return String(format: "UTC%@%02d:%02d", minutes >= 0 ? "+" : "−", abs(minutes) / 60, abs(minutes) % 60)
    }

    func time(at date: Date, language: AppLanguage = .chinese) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.timeZone = zone
        formatter.dateFormat = "EEE HH:mm"
        return formatter.string(from: date)
    }

    fileprivate var locationRuleData: Data { ruleData ?? Data(rawValue.utf8) }
}

enum ZoneCatalog {
    struct Label { let city: String; let english: String }

    static let labels: [String: Label] = {
        let chinese = DateFormatter()
        let english = DateFormatter()
        chinese.locale = Locale(identifier: "zh_CN")
        english.locale = Locale(identifier: "en_US")
        chinese.dateFormat = "VVV"
        english.dateFormat = "VVV"
        return Dictionary(uniqueKeysWithValues: Destination.allCases.map { destination in
            chinese.timeZone = destination.zone
            english.timeZone = destination.zone
            let fallback = destination.rawValue.components(separatedBy: "/").last!.replacingOccurrences(of: "_", with: " ")
            let chineseName = chinese.string(from: Date())
            let englishName = english.string(from: Date())
            let isUTC = ["Etc/UTC", "UTC"].contains(destination.rawValue)
            let city = destination.rawValue == "Asia/Shanghai"
                ? "北京 / 上海"
                : (isUTC ? "协调世界时" : (chineseName.isEmpty || chineseName == "未知城市" ? fallback : chineseName))
            let englishCity = destination.rawValue == "Asia/Shanghai"
                ? "Beijing / Shanghai"
                : (isUTC ? "Coordinated Universal Time" : (englishName.isEmpty || englishName == "Unknown City" ? fallback : englishName))
            return (destination.rawValue, Label(city: city, english: englishCity))
        })
    }()

    private struct LocationKey: Hashable {
        let city: String
        let rules: Data
    }

    private static let locations: [[Destination]] = {
        let table = (try? String(contentsOfFile: "/usr/share/zoneinfo/zone.tab", encoding: .utf8)) ?? ""
        let primary = Set(table.split(separator: "\n").compactMap { line -> String? in
            let fields = line.split(separator: "\t")
            return !line.hasPrefix("#") && fields.count >= 3 ? String(fields[2]) : nil
        })
        let grouped = Dictionary(grouping: Destination.allCases) {
            LocationKey(city: $0.englishCity, rules: $0.locationRuleData)
        }
        return grouped.values.map { members in
            members.sorted { left, right in
                let leftPrimary = left.rawValue == "Etc/UTC" || primary.contains(left.rawValue)
                let rightPrimary = right.rawValue == "Etc/UTC" || primary.contains(right.rawValue)
                if leftPrimary != rightPrimary { return leftPrimary }
                return left.rawValue < right.rawValue
            }
        }.sorted { $0[0].rawValue < $1[0].rawValue }
    }()

    static let representatives: [String: String] = Dictionary(uniqueKeysWithValues:
        locations.flatMap { members in members.map { ($0.rawValue, members[0].rawValue) } }
    )
    static let choices = locations.map { $0[0] }

    private static let searchText: [String: String] = Dictionary(uniqueKeysWithValues: locations.map { members in
        let representative = members[0]
        let names = members.map {
            "\($0.city) \($0.englishCity) \($0.rawValue.replacingOccurrences(of: "_", with: " ")) \($0.rawValue)"
        }.joined(separator: " ")
        let aliases = representative.rawValue == "Asia/Shanghai"
            ? " 北京 Beijing Peking 北京时间 中国标准时间 China Standard Time"
            : ""
        return (representative.rawValue, names + aliases)
    })

    static func search(_ query: String, at date: Date, language: AppLanguage = .chinese) -> [Destination] {
        var textQuery = query.replacingOccurrences(of: "−", with: "-")
        var offsetSeconds: Int?
        let pattern = #"(?i)\butc\s*([+-]?)\s*([0-9]{1,2})(?::([0-9]{2})|\.([0-9]{1,2}))?(?![0-9:.])"#
        let expression = try! NSRegularExpression(pattern: pattern)
        let fullRange = NSRange(textQuery.startIndex..<textQuery.endIndex, in: textQuery)
        if let match = expression.firstMatch(in: textQuery, range: fullRange) {
            func component(_ index: Int) -> String {
                guard let range = Range(match.range(at: index), in: textQuery) else { return "" }
                return String(textQuery[range])
            }
            let hours = Int(component(2))!
            let decimal = component(4)
            let minutes = decimal.isEmpty ? (Int(component(3)) ?? 0) : Int((Double("0." + decimal)! * 60).rounded())
            let sign = component(1) == "-" ? -1 : 1
            let total = sign * (hours * 3600 + minutes * 60)
            guard minutes < 60, (-12 * 3600...14 * 3600).contains(total) else { return [] }
            offsetSeconds = total
            textQuery.replaceSubrange(Range(match.range, in: textQuery)!, with: " ")
        }

        let terms = textQuery.split(whereSeparator: \.isWhitespace)
        return choices.filter { destination in
            if let offsetSeconds, destination.zone.secondsFromGMT(for: date) != offsetSeconds { return false }
            let text = (searchText[destination.rawValue] ?? "") + " " + destination.offset(at: date).replacingOccurrences(of: "−", with: "-")
            return terms.allSatisfy { text.range(of: String($0), options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }.sorted {
            let left = $0.zone.secondsFromGMT(for: date)
            let right = $1.zone.secondsFromGMT(for: date)
            if left != right { return left < right }
            let order = $0.displayCity(in: language).compare($1.displayCity(in: language), locale: Locale(identifier: language.localeIdentifier))
            return order == .orderedSame ? $0.rawValue < $1.rawValue : order == .orderedAscending
        }
    }

    struct OffsetGroup: Identifiable {
        let seconds: Int
        let title: String
        let zones: [Destination]
        var id: Int { seconds }
        var indexTitle: String {
            let minutes = abs(seconds) / 60
            let sign = seconds >= 0 ? "+" : "−"
            let hours = "\(sign)\(minutes / 60)"
            return minutes % 60 == 0 ? hours : hours + String(format: ":%02d", minutes % 60)
        }
    }

    static func groups(_ query: String, at date: Date, language: AppLanguage = .chinese) -> [OffsetGroup] {
        let grouped = Dictionary(grouping: search(query, at: date, language: language)) { $0.zone.secondsFromGMT(for: date) }
        return grouped.keys.sorted().map { seconds in
            let zones = grouped[seconds]!
            return OffsetGroup(seconds: seconds, title: zones[0].offset(at: date), zones: zones)
        }
    }
}
