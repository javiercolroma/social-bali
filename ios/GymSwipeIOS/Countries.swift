import Foundation

/// Flag emoji from a 2-letter ISO country code.
func flagEmoji(_ code: String) -> String {
    code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value).map(String.init) }.joined()
}

/// All countries from the OS, names forced to Spanish (+ flag), built once.
let allCountries: [(name: String, flag: String)] = {
    let loc = Locale(identifier: "es_ES")
    let codes = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { $0.count == 2 && $0.allSatisfy { $0.isLetter } }
    var seen = Set<String>()
    let items: [(String, String)] = codes.compactMap { code in
        guard let name = loc.localizedString(forRegionCode: code), seen.insert(name).inserted else { return nil }
        return (name, flagEmoji(code))
    }
    return items.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
}()

private let countryNameToFlag: [String: String] = Dictionary(uniqueKeysWithValues: allCountries.map { ($0.name, $0.flag) })

func countryFlag(_ name: String) -> String { countryNameToFlag[name] ?? "🌍" }
