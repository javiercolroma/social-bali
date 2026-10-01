import Foundation

/// La app tiene UN solo idioma: inglés. Muchas claves históricas de la UI siguen siendo
/// literales en español: `en.lproj/Localizable.strings` las mapea a inglés (es la única
/// localización del bundle, así que se ve en inglés sea cual sea el idioma del iPhone).
/// (La tabla de nombres de ejercicios se quitó con todo lo de entrenamiento.)
enum L10n {

    static let lang = "en"

    /// Locale fijo en inglés (fechas, números, `Text` del entorno).
    static let locale = Locale(identifier: "en")

    /// Traduce un literal de UI (clave histórica en español) a inglés, para los casos en
    /// que NO se puede usar `Text(LocalizedStringKey)`: texto que hay que manipular como
    /// String. `Text(String)` no localiza.
    static func t(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}
