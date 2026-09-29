import Foundation
import ObjectiveC

/// Bundle dinámico: redirige NSLocalizedString/Text al .lproj del idioma elegido SIN
/// reiniciar la app (swizzle clásico). Se activa en el arranque y al cambiar en Ajustes.
private var l10nBundleKey: UInt8 = 0
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table: String?) -> String {
        if let b = objc_getAssociatedObject(self, &l10nBundleKey) as? Bundle {
            return b.localizedString(forKey: key, value: value, table: table)
        }
        return super.localizedString(forKey: key, value: value, table: table)
    }
}

/// Traducción de DATOS en tiempo de render (fase 2 de i18n): los nombres de ejercicios,
/// plantillas y grupos son datos persistidos en español — no pasan por Localizable.strings.
/// `L10n.x(_:)` los traduce al idioma activo al MOSTRARLOS (los datos guardados no cambian,
/// así que nada se rompe entre idiomas). Los nombres creados por el usuario se muestran tal cual.
enum L10n {

    /// Idioma activo: el forzado en Ajustes o, si no, el del sistema.
    static var lang: String {
        if let o = UserDefaults.standard.string(forKey: "forgeLangOverride") { return o }
        return Locale.preferredLanguages.first ?? "es"
    }

    static var isSpanish: Bool { lang.hasPrefix("es") }

    /// Nombre del idioma para instruir a la IA ("responde en …").
    static var aiLanguage: String {
        let l = lang
        if l.hasPrefix("en") { return "inglés" }
        if l.hasPrefix("pt-BR") { return "portugués de Brasil" }
        if l.hasPrefix("pt") { return "portugués de Portugal" }
        if l.hasPrefix("fr") { return "francés" }
        return "español"
    }

    /// Traduce un nombre de ejercicio/plantilla/grupo si está en el catálogo; si no
    /// (nombre puesto por el usuario), lo devuelve tal cual.
    static func x(_ name: String) -> String {
        guard !isSpanish else { return name }
        guard let e = table[norm(name)] else { return name }
        let l = lang
        if l.hasPrefix("en") { return e.0 }
        if l.hasPrefix("pt-BR") { return e.2 }
        if l.hasPrefix("pt") { return e.1 }
        if l.hasPrefix("fr") { return e.3 }
        return name
    }

    private static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    /// Locale SwiftUI del idioma activo: los `Text` resuelven su localización con el
    /// locale del entorno → esta es la vía nativa para el cambio EN VIVO.
    static var locale: Locale {
        if let o = UserDefaults.standard.string(forKey: "forgeLangOverride") { return Locale(identifier: o) }
        return .current
    }

    /// Aplica el idioma AL INSTANTE (bundle dinámico para NSLocalizedString). nil = sistema.
    static func apply(_ code: String?) {
        object_setClass(Bundle.main, LocalizedBundle.self)
        let target = code.flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:))
        objc_setAssociatedObject(Bundle.main, &l10nBundleKey, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Traduce un literal de UI al idioma activo, para los casos en que NO se puede usar
    /// `Text(LocalizedStringKey)`: texto que hay que manipular como String (recortarlo,
    /// medirlo, concatenarlo). `Text(String)` no localiza, así que sin esto la cadena
    /// sale siempre en el idioma del código. Respeta el override de Ajustes.
    static func t(_ key: String) -> String {
        let bundle = UserDefaults.standard.string(forKey: "forgeLangOverride")
            .flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Llamar en el arranque: restaura el idioma forzado (si lo hay).
    static func bootstrap() {
        if let o = UserDefaults.standard.string(forKey: "forgeLangOverride") { apply(o) }
    }

    /// clave (es, normalizada) → (en, pt-PT, pt-BR, fr)
    private static let table: [String: (String, String, String, String)] = [
        // Grupos / plantillas
        "pecho": ("Chest", "Peito", "Peito", "Pectoraux"),
        "espalda": ("Back", "Costas", "Costas", "Dos"),
        "pierna": ("Legs", "Pernas", "Pernas", "Jambes"),
        "hombro": ("Shoulders", "Ombros", "Ombros", "Épaules"),
        "brazo": ("Arms", "Braços", "Braços", "Bras"),
        "abdomen": ("Abs", "Abdominais", "Abdômen", "Abdos"),
        "full body": ("Full body", "Full body", "Full body", "Full body"),
        "empuje": ("Push", "Empurrar", "Empurrar", "Poussée"),
        "tiron": ("Pull", "Puxar", "Puxar", "Tirage"),
        "otros": ("Others", "Outros", "Outros", "Autres"),
        "core": ("Core", "Core", "Core", "Core"),
        "gluteo": ("Glutes", "Glúteos", "Glúteos", "Fessiers"),
        "mi entreno": ("My workout", "O meu treino", "Meu treino", "Mon entraînement"),
        // Pecho
        "press banca": ("Bench press", "Supino", "Supino reto", "Développé couché"),
        "press inclinado con mancuernas": ("Incline dumbbell press", "Supino inclinado com halteres", "Supino inclinado com halteres", "Développé incliné haltères"),
        "aperturas en polea": ("Cable fly", "Aberturas na polia", "Crucifixo na polia", "Écarté à la poulie"),
        "aperturas": ("Fly", "Aberturas", "Crucifixo", "Écarté"),
        "fondos en paralelas": ("Parallel-bar dips", "Fundos nas paralelas", "Mergulho nas paralelas", "Dips aux barres parallèles"),
        "fondos": ("Dips", "Fundos", "Mergulho", "Dips"),
        "fondos en banco": ("Bench dips", "Fundos no banco", "Tríceps no banco", "Dips sur banc"),
        "fondos de triceps en banco": ("Bench triceps dips", "Fundos de tríceps no banco", "Tríceps no banco", "Dips triceps sur banc"),
        "press de pecho en maquina": ("Machine chest press", "Press de peito na máquina", "Supino na máquina", "Presse à pectoraux"),
        "flexiones": ("Push-ups", "Flexões", "Flexão de braço", "Pompes"),
        // Espalda
        "dominadas": ("Pull-ups", "Elevações na barra", "Barra fixa", "Tractions"),
        "remo con barra": ("Barbell row", "Remada com barra", "Remada curvada", "Rowing barre"),
        "jalon al pecho": ("Lat pulldown", "Puxada ao peito", "Puxada frontal", "Tirage vertical"),
        "remo con mancuerna": ("Dumbbell row", "Remada com halter", "Remada serrote", "Rowing haltère"),
        "remo en polea": ("Cable row", "Remada na polia", "Remada na polia", "Rowing poulie"),
        "face pull": ("Face pull", "Face pull", "Face pull", "Face pull"),
        // Pierna
        "sentadilla": ("Squat", "Agachamento", "Agachamento", "Squat"),
        "sentadilla trasera": ("Back squat", "Agachamento atrás", "Agachamento livre", "Squat arrière"),
        "sentadilla bulgara": ("Bulgarian split squat", "Agachamento búlgaro", "Agachamento búlgaro", "Squat bulgare"),
        "prensa de piernas": ("Leg press", "Prensa de pernas", "Leg press", "Presse à cuisses"),
        "peso muerto rumano": ("Romanian deadlift", "Peso morto romeno", "Terra romeno", "Soulevé de terre roumain"),
        "peso muerto": ("Deadlift", "Peso morto", "Levantamento terra", "Soulevé de terre"),
        "curl femoral tumbado": ("Lying leg curl", "Leg curl deitado", "Mesa flexora", "Leg curl allongé"),
        "curl femoral": ("Leg curl", "Leg curl", "Cadeira flexora", "Leg curl"),
        "extension de cuadriceps": ("Leg extension", "Extensão de quadríceps", "Cadeira extensora", "Leg extension"),
        "elevacion de gemelos": ("Calf raise", "Elevação de gémeos", "Elevação de panturrilha", "Extension mollets"),
        "zancadas": ("Lunges", "Afundos", "Afundo", "Fentes"),
        "hip thrust": ("Hip thrust", "Hip thrust", "Elevação pélvica", "Hip thrust"),
        // Hombro
        "press militar": ("Overhead press", "Press militar", "Desenvolvimento militar", "Développé militaire"),
        "elevaciones laterales": ("Lateral raises", "Elevações laterais", "Elevação lateral", "Élévations latérales"),
        "press arnold": ("Arnold press", "Press Arnold", "Desenvolvimento Arnold", "Développé Arnold"),
        "pajaros (deltoide posterior)": ("Rear-delt fly", "Aberturas invertidas", "Crucifixo inverso", "Oiseau"),
        "pajaros": ("Rear-delt fly", "Aberturas invertidas", "Crucifixo inverso", "Oiseau"),
        "elevaciones frontales": ("Front raises", "Elevações frontais", "Elevação frontal", "Élévations frontales"),
        // Brazo
        "curl de biceps con barra": ("Barbell biceps curl", "Curl de bíceps com barra", "Rosca direta", "Curl biceps barre"),
        "curl con barra": ("Barbell curl", "Curl com barra", "Rosca direta", "Curl barre"),
        "curl martillo": ("Hammer curl", "Curl martelo", "Rosca martelo", "Curl marteau"),
        "curl inclinado": ("Incline curl", "Curl inclinado", "Rosca inclinada", "Curl incliné"),
        "curl predicador": ("Preacher curl", "Curl no banco Scott", "Rosca Scott", "Curl pupitre"),
        "press frances": ("Skull crushers", "Press francês", "Tríceps testa", "Barre au front"),
        "extension de triceps en polea": ("Triceps pushdown", "Extensão de tríceps na polia", "Tríceps na polia", "Extension triceps poulie"),
        // Core
        "plancha": ("Plank", "Prancha", "Prancha", "Planche"),
        "crunch": ("Crunch", "Crunch", "Abdominal crunch", "Crunch"),
        "giro ruso": ("Russian twist", "Rotação russa", "Rotação russa", "Twist russe"),
        "elevacion de piernas": ("Leg raises", "Elevação de pernas", "Elevação de pernas", "Relevé de jambes"),
    ]
}
