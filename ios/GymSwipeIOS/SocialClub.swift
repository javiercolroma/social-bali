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

    /// Etiqueta del perfil y del selector.
    var label: String {
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
    var blurb: String {
        switch self {
        case .training: return "Gym, surf, runs — people to move with"
        case .friends:  return "Expand my circle here"
        case .dating:   return "Open to meeting someone"
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

    var label: String {
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
        case .livingHere: return "Living here"
        case .longTerm:   return "Here long term"
        case .until:
            guard let until else { return "Here long term" }
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "MMM d"
            return "In Bali until \(f.string(from: until))"
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
        case 0:      return "Leaves today"
        case 1:      return "1 day left"
        case 2...13: return "\(d) days left"
        case 14...20: return "2 weeks left"
        case 21...27: return "3 weeks left"
        default:     return nil
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

    var label: String {
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

    var label: String {
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
