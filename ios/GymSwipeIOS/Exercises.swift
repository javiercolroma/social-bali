import Foundation

/// Curated professional exercise catalog (strength + hybrid/functional + cardio
/// + calisthenics). Users can also type a custom exercise not in the list.
let exerciseCatalog: [String] = [
    // Pecho
    "Press banca", "Press banca con mancuernas", "Press inclinado con barra", "Press inclinado con mancuernas",
    "Press declinado", "Aperturas con mancuernas", "Aperturas en polea", "Fondos en paralelas", "Flexiones",
    "Press de pecho en máquina", "Pullover",
    // Espalda
    "Dominadas", "Dominadas lastradas", "Jalón al pecho", "Jalón agarre cerrado", "Remo con barra",
    "Remo con mancuerna", "Remo en polea baja", "Remo en punta (T-bar)", "Remo Pendlay", "Peso muerto",
    "Peso muerto sumo", "Face pull", "Encogimientos de trapecio", "Hiperextensiones",
    // Pierna
    "Sentadilla trasera", "Sentadilla frontal", "Sentadilla goblet", "Hack squat", "Prensa de piernas",
    "Zancadas", "Zancadas caminando", "Sentadilla búlgara", "Peso muerto rumano", "Hip thrust",
    "Curl femoral tumbado", "Curl femoral sentado", "Extensión de cuádriceps", "Elevación de gemelos",
    "Gemelo sentado", "Abductores", "Aductores", "Step up",
    // Hombro
    "Press militar", "Press militar con mancuernas", "Press Arnold", "Elevaciones laterales",
    "Elevaciones frontales", "Pájaros (deltoide posterior)", "Remo al mentón", "Face pull",
    // Brazos
    "Curl de bíceps con barra", "Curl de bíceps con mancuernas", "Curl martillo", "Curl predicador",
    "Curl en polea", "Extensión de tríceps en polea", "Press francés", "Fondos de tríceps en banco",
    "Patada de tríceps", "Extensión de tríceps sobre la cabeza",
    // Core
    "Plancha", "Plancha lateral", "Crunch", "Crunch en polea", "Elevación de piernas colgado",
    "Rueda abdominal", "Russian twist", "Hollow hold", "Mountain climbers", "Dead bug",
    // Híbrido / Funcional / CrossFit
    "Thruster", "Clean (cargada)", "Power clean", "Hang clean", "Snatch (arrancada)", "Clean and jerk",
    "Wall ball", "Box jump", "Burpee", "Kettlebell swing", "Turkish get-up", "Devil press",
    "Sled push (empuje de trineo)", "Sled pull", "Farmer carry (paseo del granjero)", "Battle ropes",
    "Slam ball", "Thruster con mancuernas", "Man maker", "Wall walk",
    // Calistenia
    "Muscle up", "Pistol squat", "Fondos en anillas", "L-sit", "Pino (handstand)", "Flexión en pino",
    // Cardio / Conditioning
    "Carrera continua", "Cinta de correr", "Sprints", "Remo (rower)", "Assault bike", "Bici estática",
    "Spinning", "Elíptica", "Comba (saltar a la cuerda)", "Double unders", "Natación", "Escaladora (stairmaster)",
    "Caminata inclinada", "Sprint en cuesta",
]

func searchExercises(_ query: String) -> [String] {
    let q = query.folding(options: .diacriticInsensitive, locale: .current)
        .lowercased().trimmingCharacters(in: .whitespaces)
    if q.isEmpty { return Array(exerciseCatalog.prefix(8)) }
    let matches = exerciseCatalog.filter {
        $0.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
    }
    // Exact match shouldn't be suggested (already typed)
    return matches.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
}
