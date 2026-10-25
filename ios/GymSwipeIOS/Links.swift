import Foundation

/// Páginas públicas y contacto de Bali Circle (GitHub Pages del repo forgeloop-legal).
/// Las mismas URLs van en la ficha de App Store Connect.
enum Links {
    static let site = "https://javiercolroma.github.io/forgeloop-legal/balicircle"
    static let privacy = URL(string: site + "/privacy.html")!
    static let terms = URL(string: site + "/terms.html")!
    static let guidelines = URL(string: site + "/guidelines.html")!
    static let support = URL(string: site + "/support.html")!
    static let supportEmail = "soporte@forgeloop.app"

    /// «1.0 (20)»
    static var versionLabel: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }
}
