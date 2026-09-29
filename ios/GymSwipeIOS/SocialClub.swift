import Foundation

/// Dominio del **club social** (ver `PRODUCT.md`): identidad de la persona, no del atleta.
/// Todo lo que hay aquí alimenta Discover y la tarjeta de perfil: deportes, barrio, de
/// dónde eres, cuánto te quedas en Bali y qué tipo de conexiones buscas.
///
/// Idioma: las cadenas se escriben en **inglés** (idioma base del producto desde
/// 2026-09-28) y se traducen en `es/fr/pt.lproj`.

// MARK: - Tipos de conexión (§3)

/// Qué busca una persona. **Multi-selección** y NO crea compartimentos separados: solo
/// afina Discover. Una sola comunidad, no tres apps dentro de una.
enum ConnectionIntent: String, Codable, CaseIterable, Identifiable {
    case training, friends, dating

    var id: String { rawValue }

    /// Etiqueta del perfil y del selector, ya traducida (ver `L10n.t`).
    var label: String { L10n.t(labelKey) }

    private var labelKey: String {
        switch self {
        case .training: return "Training"
        case .friends:  return "Friends"
        case .dating:   return "Dating"
        }
    }

    var icon: String {
        switch self {
        case .training: return "figure.strengthtraining.traditional"
        case .friends:  return "person.2.fill"
        case .dating:   return "sparkles"
        }
    }

    /// Frase corta que explica la intención sin sonar a formulario.
    var blurb: String { L10n.t(blurbKey) }

    private var blurbKey: String {
        switch self {
        case .training: return "Gym, surf, runs — people to move with"
        case .friends:  return "Expand my circle here"
        case .dating:   return "Open to meeting someone"
        }
    }
}

// MARK: - Género

/// El valor que se GUARDA es un código estable (`man`), no el texto que se enseña.
/// Antes se persistía la etiqueta visible («Hombre»), así que al pasar el producto a
/// inglés el onboarding escribía «Man» y el selector del perfil seguía ofreciendo
/// «Hombre»: dejaban de casar y el campo aparecía vacío. `from(_:)` es tolerante con
/// lo ya guardado —español o inglés— para no perder el dato de nadie.
enum Gender: String, Codable, CaseIterable, Identifiable {
    case man, woman, other

    var id: String { rawValue }

    var label: String { L10n.t(labelKey) }

    private var labelKey: String {
        switch self {
        case .man: return "Man"
        case .woman: return "Woman"
        case .other: return "Other"
        }
    }

    static func from(_ raw: String?) -> Gender? {
        guard let r = raw?.trimmingCharacters(in: .whitespaces).lowercased(), !r.isEmpty else { return nil }
        switch r {
        case "man", "hombre", "male", "homme", "homem":       return .man
        case "woman", "mujer", "female", "femme", "mulher":   return .woman
        case "other", "otro", "autre", "outro", "non-binary": return .other
        default: return nil
        }
    }
}

// MARK: - Situación en Bali (§10)

/// Cuánto tiempo se queda esa persona. Es **información crítica**, no un detalle
/// escondido: cambia por completo la utilidad de una conexión.
enum StayKind: String, Codable, CaseIterable, Identifiable {
    case livingHere      // vive aquí, sin fecha de salida
    case longTerm        // meses, sin fecha cerrada
    case until           // se va un día concreto (usa `stayUntil`)

    var id: String { rawValue }

    var label: String { L10n.t(labelKey) }

    private var labelKey: String {
        switch self {
        case .livingHere: return "Living here"
        case .longTerm:   return "Here long term"
        case .until:      return "Leaving on a date"
        }
    }
}

/// Estancia ya resuelta para MOSTRAR. Encapsula la regla de «2 weeks left» para que no
/// se reimplemente en cada pantalla.
struct Stay: Equatable {
    let kind: StayKind
    let until: Date?

    /// Texto principal: "Living here", "In Bali until Nov 12", "Here long term".
    var headline: String {
        switch kind {
        case .livingHere: return L10n.t("Living here")
        case .longTerm:   return L10n.t("Here long term")
        case .until:
            guard let until else { return L10n.t("Here long term") }
            let f = DateFormatter()
            f.locale = L10n.locale
            f.setLocalizedDateFormatFromTemplate("MMMd")
            return String(format: L10n.t("In Bali until %@"), f.string(from: until))
        }
    }

    /// Días que le quedan (solo si hay fecha y no ha pasado).
    var daysLeft: Int? {
        guard kind == .until, let until else { return nil }
        let d = Calendar.current.dateComponents([.day], from: Date(), to: until).day ?? 0
        return d >= 0 ? d : nil
    }

    /// Aviso de urgencia: se muestra aparte cuando queda poco («2 weeks left»).
    /// nil cuando falta mucho o vive aquí — así el aviso conserva su fuerza.
    var urgency: String? {
        guard let d = daysLeft else { return nil }
        switch d {
        case 0:       return L10n.t("Leaves today")
        case 1:       return L10n.t("1 day left")
        case 2...13:  return String(format: L10n.t("%lld days left"), d)
        case 14...20: return L10n.t("2 weeks left")
        case 21...27: return L10n.t("3 weeks left")
        default:      return nil
        }
    }

    /// ¿Se marcha pronto? Discover lo usa para no proponer a quien ya se ha ido.
    var isLeavingSoon: Bool { (daysLeft ?? .max) <= 13 }
}

// MARK: - Deportes (§4, §13)

/// Catálogo de deportes del club. Pensado para **Bali**: surf y wellness al mismo nivel
/// que el gimnasio. Es identidad, no una lista exhaustiva de disciplinas.
enum Sport: String, Codable, CaseIterable, Identifiable {
    case surf, gym, running, yoga, pilates, padel, tennis, muayThai, boxing, bjj
    case climbing, cycling, swimming, beachVolleyball, skate, freediving, kitesurf
    case crossfit, hiking, dance, golf, basketball, football

    var id: String { rawValue }

    var label: String { L10n.t(labelKey) }

    private var labelKey: String {
        switch self {
        case .surf: return "Surf"
        case .gym: return "Gym"
        case .running: return "Running"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .padel: return "Padel"
        case .tennis: return "Tennis"
        case .muayThai: return "Muay Thai"
        case .boxing: return "Boxing"
        case .bjj: return "BJJ"
        case .climbing: return "Climbing"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .beachVolleyball: return "Beach volleyball"
        case .skate: return "Skate"
        case .freediving: return "Freediving"
        case .kitesurf: return "Kitesurf"
        case .crossfit: return "CrossFit"
        case .hiking: return "Hiking"
        case .dance: return "Dance"
        case .golf: return "Golf"
        case .basketball: return "Basketball"
        case .football: return "Football"
        }
    }

    var emoji: String {
        switch self {
        case .surf: return "🏄"
        case .gym: return "🏋️"
        case .running: return "🏃"
        case .yoga: return "🧘"
        case .pilates: return "🤸"
        case .padel: return "🎾"
        case .tennis: return "🎾"
        case .muayThai: return "🥊"
        case .boxing: return "🥊"
        case .bjj: return "🥋"
        case .climbing: return "🧗"
        case .cycling: return "🚴"
        case .swimming: return "🏊"
        case .beachVolleyball: return "🏐"
        case .skate: return "🛹"
        case .freediving: return "🤿"
        case .kitesurf: return "🪁"
        case .crossfit: return "💪"
        case .hiking: return "🥾"
        case .dance: return "💃"
        case .golf: return "⛳"
        case .basketball: return "🏀"
        case .football: return "⚽"
        }
    }

    /// Orden de presentación: primero lo que define a la comunidad de Bali.
    static let curated: [Sport] = [
        .surf, .gym, .yoga, .running, .pilates, .padel, .muayThai, .crossfit,
        .swimming, .freediving, .climbing, .cycling, .beachVolleyball, .tennis,
        .boxing, .bjj, .kitesurf, .skate, .hiking, .dance, .basketball, .football, .golf,
    ]

    /// Tolerante con valores viejos o desconocidos (el servidor guarda `rawValue`).
    static func from(_ raw: String) -> Sport? { Sport(rawValue: raw) }
}

// MARK: - Barrios (§9)

/// Zonas donde arranca el club. Es un campo **declarado**, no derivado del GPS: la
/// presencia se redondea a celdas de ~5,5 km y Canggu, Berawa y Pererenan caben en 3 km
/// (serían indistinguibles). Declararlo sale más privado *y* socialmente más preciso.
enum Neighborhood: String, Codable, CaseIterable, Identifiable {
    case canggu, berawa, pererenan, seminyak, umalas, uluwatu, bingin, pecatu
    case ubud, sanur, denpasar, nusaDua, amed, other

    var id: String { rawValue }

    /// Los nombres propios no se traducen; solo «Elsewhere in Bali».
    var label: String { self == .other ? L10n.t("Elsewhere in Bali") : labelKey }

    private var labelKey: String {
        switch self {
        case .canggu: return "Canggu"
        case .berawa: return "Berawa"
        case .pererenan: return "Pererenan"
        case .seminyak: return "Seminyak"
        case .umalas: return "Umalas"
        case .uluwatu: return "Uluwatu"
        case .bingin: return "Bingin"
        case .pecatu: return "Pecatu"
        case .ubud: return "Ubud"
        case .sanur: return "Sanur"
        case .denpasar: return "Denpasar"
        case .nusaDua: return "Nusa Dua"
        case .amed: return "Amed"
        case .other: return "Elsewhere in Bali"
        }
    }

    /// Zonas del arranque (§9): la densidad se concentra aquí primero.
    static let launchAreas: [Neighborhood] = [.canggu, .berawa, .pererenan, .uluwatu, .bingin, .pecatu]

    var isLaunchArea: Bool { Neighborhood.launchAreas.contains(self) }
}

// MARK: - Identidad del club (lo que se PINTA)

/// La identidad de una persona tal y como se muestra: la propia (desde `Profile`) y la
/// de los demás (desde `ProfileRow` → `SocialPerson`). Un solo tipo para que el perfil
/// propio, el ajeno y —más adelante— Discover lean exactamente lo mismo.
///
/// Guarda TEXTO (`rawValue`), no enums: viaja dentro de `SocialPerson`, que se persiste
/// en el dispositivo, y un deporte que añada una versión futura haría fallar el decode
/// entero en una anterior. Los accesos tipados descartan lo que no reconocen.
struct ClubIdentity: Codable, Hashable {
    var bio: String? = nil
    var sports: [String]? = nil
    var neighborhood: String? = nil
    var homeCity: String? = nil
    var homeCountry: String? = nil
    var stayKind: String? = nil
    var stayUntil: Date? = nil
    var intents: [String]? = nil

    var sportList: [Sport] { (sports ?? []).compactMap(Sport.from) }
    var intentList: [ConnectionIntent] { (intents ?? []).compactMap(ConnectionIntent.init(rawValue:)) }
    var area: Neighborhood? { neighborhood.flatMap(Neighborhood.init(rawValue:)) }
    var stay: Stay? { stayKind.flatMap(StayKind.init(rawValue:)).map { Stay(kind: $0, until: stayUntil) } }

    var trimmedBio: String? {
        let b = bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return b.isEmpty ? nil : b
    }

    /// «Barcelona 🇪🇸». Solo la ciudad cuando la hay: los países se guardan con su nombre
    /// en español (ver `allCountries`) y leerlos en inglés quedaría a medias.
    var homeLine: String? {
        let city = homeCity?.trimmingCharacters(in: .whitespaces) ?? ""
        let country = homeCountry?.trimmingCharacters(in: .whitespaces) ?? ""
        if city.isEmpty && country.isEmpty { return nil }
        let flag = country.isEmpty ? "" : " " + countryFlag(country)
        return (city.isEmpty ? country : city) + flag
    }

    /// Como la ve otra persona: «dating» solo aparece a quien también lo busca (y puede).
    /// Descubrir ya lo recibe filtrado del servidor; el perfil completo lo filtra aquí.
    func visible(toViewerOpenToDating viewerDates: Bool) -> ClubIdentity {
        guard !viewerDates else { return self }
        var c = self
        c.intents = intents?.filter { $0 != ConnectionIntent.dating.rawValue }
        return c
    }

    /// Nada que enseñar: el perfil ajeno oculta la tarjeta; el propio invita a rellenarla.
    var isEmpty: Bool {
        trimmedBio == nil && sportList.isEmpty && area == nil && homeLine == nil
            && stay == nil && intentList.isEmpty
    }
}

// MARK: - Edad mínima para «Dating»

/// Requisito de la App Store para una app con intención de citas. Sin fecha de
/// nacimiento la edad NO se presupone. El servidor aplica la misma regla
/// (migración 0024), así que un cliente viejo tampoco puede saltársela.
enum AgeGate {
    static let datingMinAge = 18

    static func isAdult(_ birthdate: Date?, now: Date = Date()) -> Bool {
        guard let birthdate else { return false }
        let years = Calendar.current.dateComponents([.year], from: birthdate, to: now).year ?? 0
        return years >= datingMinAge
    }
}
