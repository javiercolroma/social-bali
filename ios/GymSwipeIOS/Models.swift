import Foundation

/// Perfil propio. `gym` y las redes sociales son campos heredados: se conservan para
/// poder decodificar datos locales antiguos, pero la app ya no los pide ni los enseña.
struct Profile: Codable {
    var sex: String
    var age: String
    var country: String
    var city: String
    var gym: String
    var region: String? = nil
    var birthdate: Date? = nil
    var isPrivate: Bool = false
    var instagram: String? = nil
    var tiktok: String? = nil
    var twitter: String? = nil

    // ─── Club social (PRODUCT.md · Fase 1 «Identidad») ───────────────────────────
    // TODO opcional: son perfiles ya guardados los que se decodifican, y un campo no
    // opcional que falte hace fallar TODO el decode (ya nos costó una pérdida de datos).
    // Se guardan `rawValue` en texto plano para que el servidor no dependa del enum.

    /// Bio de una línea. Es lo que da personalidad a la tarjeta de Discover:
    /// «Sunrise surf → coffee → work.»
    var bio: String? = nil
    /// Deportes (rawValue de `Sport`). Identidad + filtro natural de comunidad.
    var sports: [String]? = nil
    /// Barrio DECLARADO dentro de Bali (rawValue de `Neighborhood`). Ver SocialClub.swift
    /// sobre por qué no se deriva del GPS.
    var neighborhood: String? = nil
    /// De dónde eres (≠ dónde estás). Alimenta el «Barcelona 🇪🇸» de la tarjeta.
    var homeCity: String? = nil
    var homeCountry: String? = nil
    /// Situación en Bali (rawValue de `StayKind`) + fecha de salida si la hay.
    var stayKind: String? = nil
    var stayUntil: Date? = nil
    /// Qué tipo de conexiones busca (rawValue de `ConnectionIntent`), multi-selección.
    var intents: [String]? = nil
    /// Fotos antiguas (0027). La galería nueva es `media`.
    var photos: [String]? = nil
    /// Galería del perfil: hasta 9 fotos, vídeos o Live Photos; la primera es la principal.
    var media: [MediaItem]? = nil
    /// Si aún no está en Bali: cuándo llega (el Circle se abre al llegar).
    var arrivalDate: Date? = nil

    // ─── Accesos tipados (el almacenamiento es texto; la app trabaja con enums) ───

    var sportList: [Sport] {
        get { (sports ?? []).compactMap(Sport.from) }
        set { sports = newValue.map(\.rawValue) }
    }

    var intentList: [ConnectionIntent] {
        get { (intents ?? []).compactMap(ConnectionIntent.init(rawValue:)) }
        set { intents = newValue.map(\.rawValue) }
    }

    var area: Neighborhood? {
        get { neighborhood.flatMap(Neighborhood.init(rawValue:)) }
        set { neighborhood = newValue?.rawValue }
    }

    /// ¿Puede activar «Dating»? Ver `AgeGate`.
    var canDate: Bool { AgeGate.isAdult(birthdate) }

    /// Quita «dating» si la edad no lo permite (fecha borrada, cambiada a menor o
    /// datos de antes de la regla). Se aplica en cada guardado: así el servidor nunca
    /// recibe un perfil que rechazaría — y con él se perdería la subida ENTERA.
    mutating func enforceDatingAge() {
        guard !canDate, intentList.contains(.dating) else { return }
        intentList = intentList.filter { $0 != .dating }
    }

    /// Identidad del club lista para mostrar (misma forma que la de los demás).
    var club: ClubIdentity {
        ClubIdentity(bio: bio, sports: sports, neighborhood: neighborhood, homeCity: homeCity,
                     homeCountry: homeCountry, stayKind: stayKind, stayUntil: stayUntil, intents: intents)
    }

    /// Estancia resuelta para mostrar; nil si la persona aún no la ha indicado.
    var stay: Stay? {
        guard let k = stayKind.flatMap(StayKind.init(rawValue:)) else { return nil }
        return Stay(kind: k, until: stayUntil)
    }

    /// ¿Tiene el perfil lo mínimo para aparecer en Discover? (§11 «perfil mínimo
    /// obligatorio»): sin esto la tarjeta sale vacía y no se puede decidir nada.
    var isClubReady: Bool {
        !(bio ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sportList.isEmpty
            && area != nil
            && stay != nil
            && !intentList.isEmpty
    }
}

// MARK: - Social

/// Sesión iniciada (identidad del proveedor). Sin backend todavía: se guarda local.
struct Auth: Codable, Equatable {
    var provider: String      // "apple" | "google" | "email"
    var userId: String
    var email: String? = nil
    var name: String? = nil
}

struct Account: Codable, Equatable {
    var name: String
    var handle: String
    var photoData: Data? = nil
    var photoScale: Double? = nil
    var photoOffsetX: Double? = nil
    var photoOffsetY: Double? = nil
}

struct SocialPerson: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var handle: String
    var avatar: String
    var gym: String
    var flag: String = "🇪🇸"
    var city: String = "Madrid"
    var country: String = "Spain"
    var isPrivate: Bool = false
    /// Foto real del avatar (Storage) para usuarios reales; el emoji queda de fallback.
    var avatarURL: String? = nil
    /// Identidad del club (bio, deportes, barrio, estancia…). nil = no cargada / demo.
    var club: ClubIdentity? = nil
    /// Sus fotos de actividad + las de sus últimos entrenos públicos (Descubrir).
    var photos: [String]? = nil
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: String
    var fromMe: Bool
    var text: String
    var at: Date
    // ─── Chat tipo WhatsApp (0033). Opcionales: los mensajes guardados antes no los tienen.
    var kind: String? = nil          // text · image · video · location · audio
    var mediaURL: String? = nil
    var posterURL: String? = nil
    var w: Int? = nil
    var h: Int? = nil
    var duration: Double? = nil
    var lat: Double? = nil
    var lon: Double? = nil
    /// Lo ha leído la otra persona (para el doble check azul).
    var read: Bool? = nil

    var type: String { kind ?? "text" }

    /// Marcador de los entrenos compartidos de versiones anteriores (se quitaron de la app).
    private static let legacyWorkoutMarker = "\u{1FAAF}FORGE-WKT1::"
    /// Mensaje antiguo con un entreno codificado: no se enseña su contenido crudo.
    var isLegacyWorkout: Bool { text.hasPrefix(Self.legacyWorkoutMarker) }
    /// Texto legible para la lista de conversaciones y la burbuja del chat.
    var preview: String {
        switch type {
        case "image": return "📷 " + L10n.t("Photo")
        case "video": return "🎥 " + L10n.t("Video")
        case "location": return "📍 " + L10n.t("Location")
        case "audio": return "🎤 " + L10n.t("Voice message")
        default: return isLegacyWorkout ? L10n.t("This message is no longer supported") : text
        }
    }
}

struct Conversation: Identifiable, Codable, Hashable {
    var id: String
    var personId: String
    var messages: [ChatMessage]
    var unread: Int
    var lastAt: Date
    var lastMessage: ChatMessage? { messages.last }
}
