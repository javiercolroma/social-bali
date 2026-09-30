import Foundation

/// Flag emoji from a 2-letter ISO country code.
func flagEmoji(_ code: String) -> String {
    code.uppercased().unicodeScalars.compactMap { UnicodeScalar(127397 + $0.value).map(String.init) }.joined()
}

private let isoCountryCodes: [String] = Locale.Region.isoRegions
    .map(\.identifier)
    .filter { $0.count == 2 && $0.allSatisfy { $0.isLetter } }

/// All countries from the OS, names in English (+ flag), built once.
let allCountries: [(name: String, flag: String)] = {
    let loc = Locale(identifier: "en")
    var seen = Set<String>()
    let items: [(String, String)] = isoCountryCodes.compactMap { code in
        guard let name = loc.localizedString(forRegionCode: code), seen.insert(name).inserted else { return nil }
        return (name, flagEmoji(code))
    }
    return items.sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
}()

/// Los perfiles antiguos guardaron el país con su nombre en español: nombre (es) → código.
private let legacySpanishCountryCodes: [String: String] = {
    let loc = Locale(identifier: "es_ES")
    var d: [String: String] = [:]
    for code in isoCountryCodes { if let n = loc.localizedString(forRegionCode: code), d[n] == nil { d[n] = code } }
    return d
}()

private let countryNameToFlag: [String: String] = Dictionary(allCountries.map { ($0.name, $0.flag) }, uniquingKeysWith: { a, _ in a })

func countryFlag(_ name: String) -> String {
    if let f = countryNameToFlag[name] { return f }
    if let code = legacySpanishCountryCodes[name] { return flagEmoji(code) }
    return "🌍"
}

/// Nombre del país para MOSTRAR (en inglés), aunque esté guardado en español.
func countryName(_ name: String) -> String {
    guard countryNameToFlag[name] == nil, let code = legacySpanishCountryCodes[name] else { return name }
    return Locale(identifier: "en").localizedString(forRegionCode: code) ?? name
}
