import Foundation

/// Catálogo profesional de ejercicios (fuerza + híbrido/funcional + cardio + calistenia).
/// El usuario también puede escribir uno propio que no esté en la lista.
///
/// Está AGRUPADO por dos motivos: (1) alimentar al generador de entrenos de Forgey con
/// SOLO los grupos que pide el usuario — el modelo on-device tiene contexto corto y no
/// caben 130 ejercicios; (2) que «isquios» ofrezca de verdad todo lo que hay y no dos
/// opciones. Las `keywords` son cómo la gente NOMBRA el grupo al pedirlo.
struct ExerciseGroup {
    let name: String
    let keywords: [String]
    let items: [String]
}

let exerciseGroups: [ExerciseGroup] = [
    ExerciseGroup(name: "Pecho", keywords: ["pecho", "pectoral", "press banca", "empuje", "torso", "chest", "pecs", "bench", "push"], items: [
        "Press banca", "Press banca con mancuernas", "Press inclinado con barra", "Press inclinado con mancuernas",
        "Press declinado", "Aperturas con mancuernas", "Aperturas en polea", "Fondos en paralelas", "Flexiones",
        "Press de pecho en máquina", "Pullover",
    ]),
    ExerciseGroup(name: "Espalda", keywords: ["espalda", "dorsal", "tiron", "tirón", "remo", "torso", "pull", "back", "lats", "row"], items: [
        "Dominadas", "Dominadas lastradas", "Jalón al pecho", "Jalón agarre cerrado", "Remo con barra",
        "Remo con mancuerna", "Remo en polea baja", "Remo en punta (T-bar)", "Remo Pendlay", "Peso muerto",
        "Peso muerto sumo", "Face pull", "Encogimientos de trapecio", "Hiperextensiones",
    ]),
    // Isquiosurales y glúteo: el grupo que peor cubierto estaba (solo «peso muerto rumano»
    // y «curl femoral» llegaban al prompt). Es la cadena posterior al completo.
    ExerciseGroup(name: "Isquiosurales y glúteo", keywords: ["isquio", "isquios", "isquiotibial", "femoral", "gluteo", "glúteo", "cadena posterior", "bisagra", "hamstring", "glute", "posterior chain", "hinge"], items: [
        "Peso muerto rumano", "Peso muerto rumano con mancuernas", "Peso muerto a una pierna",
        "Peso muerto piernas rígidas", "Buenos días (good morning)", "Curl femoral tumbado",
        "Curl femoral sentado", "Curl femoral de pie", "Curl nórdico", "Glute-ham raise",
        "Hip thrust", "Puente de glúteo", "Patada de glúteo en polea", "Abducción de cadera en máquina",
        "Zancada inversa", "Sentadilla búlgara", "Buenos días con barra", "Curl femoral con fitball",
        "Hiperextensiones", "Sled pull",
    ]),
    ExerciseGroup(name: "Cuádriceps", keywords: ["cuadriceps", "cuádriceps", "pierna", "piernas", "tren inferior", "sentadilla", "quad", "legs", "lower body", "squat"], items: [
        "Sentadilla trasera", "Sentadilla frontal", "Sentadilla goblet", "Hack squat", "Prensa de piernas",
        "Zancadas", "Zancadas caminando", "Sentadilla búlgara", "Extensión de cuádriceps", "Step up",
        "Sentadilla sissy", "Prensa a una pierna", "Pistol squat",
    ]),
    ExerciseGroup(name: "Gemelo", keywords: ["gemelo", "gemelos", "pantorrilla", "soleo", "sóleo", "pierna", "calf", "calves"], items: [
        "Elevación de gemelos", "Gemelo sentado", "Elevación de gemelos en prensa", "Salto a la comba",
    ]),
    ExerciseGroup(name: "Aductores y abductores", keywords: ["aductor", "abductor", "cadera", "pierna", "adductor", "hip"], items: [
        "Abductores", "Aductores", "Zancada lateral", "Sentadilla sumo",
    ]),
    ExerciseGroup(name: "Hombro", keywords: ["hombro", "hombros", "deltoide", "empuje", "shoulder", "delts"], items: [
        "Press militar", "Press militar con mancuernas", "Press Arnold", "Elevaciones laterales",
        "Elevaciones frontales", "Pájaros (deltoide posterior)", "Remo al mentón", "Face pull",
        "Elevaciones laterales en polea", "Press tras nuca",
    ]),
    ExerciseGroup(name: "Bíceps", keywords: ["biceps", "bíceps", "brazo", "brazos", "arms"], items: [
        "Curl de bíceps con barra", "Curl de bíceps con mancuernas", "Curl martillo", "Curl predicador",
        "Curl en polea", "Curl concentrado", "Curl inclinado", "Curl araña",
    ]),
    ExerciseGroup(name: "Tríceps", keywords: ["triceps", "tríceps", "brazo", "brazos", "empuje", "arms"], items: [
        "Extensión de tríceps en polea", "Press francés", "Fondos de tríceps en banco", "Patada de tríceps",
        "Extensión de tríceps sobre la cabeza", "Press cerrado", "Extensión de tríceps con cuerda",
    ]),
    ExerciseGroup(name: "Core", keywords: ["core", "abdominal", "abdominales", "abs", "oblicuo", "lumbar"], items: [
        "Plancha", "Plancha lateral", "Crunch", "Crunch en polea", "Elevación de piernas colgado",
        "Rueda abdominal", "Russian twist", "Hollow hold", "Mountain climbers", "Dead bug",
        "Pallof press", "Elevación de piernas tumbado",
    ]),
    ExerciseGroup(name: "Híbrido y funcional", keywords: ["funcional", "crossfit", "hibrido", "híbrido", "wod", "metcon", "functional", "hybrid", "hyrox"], items: [
        "Thruster", "Clean (cargada)", "Power clean", "Hang clean", "Snatch (arrancada)", "Clean and jerk",
        "Wall ball", "Box jump", "Burpee", "Kettlebell swing", "Turkish get-up", "Devil press",
        "Sled push (empuje de trineo)", "Sled pull", "Farmer carry (paseo del granjero)", "Battle ropes",
        "Slam ball", "Thruster con mancuernas", "Man maker", "Wall walk",
    ]),
    ExerciseGroup(name: "Calistenia", keywords: ["calistenia", "peso corporal", "sin material", "casa", "calisthenics", "bodyweight", "no equipment", "home"], items: [
        "Muscle up", "Pistol squat", "Fondos en anillas", "L-sit", "Pino (handstand)", "Flexión en pino",
        "Flexiones", "Dominadas", "Fondos en paralelas",
    ]),
    ExerciseGroup(name: "Cardio", keywords: ["cardio", "correr", "carrera", "resistencia", "aerobico", "aeróbico", "quemar", "running", "run", "endurance"], items: [
        "Carrera continua", "Cinta de correr", "Sprints", "Remo (rower)", "Assault bike", "Bici estática",
        "Spinning", "Elíptica", "Comba (saltar a la cuerda)", "Double unders", "Natación",
        "Escaladora (stairmaster)", "Caminata inclinada", "Sprint en cuesta",
    ]),
]

/// Lista plana (sin duplicados, conservando el orden) para el buscador de la UI.
let exerciseCatalog: [String] = {
    var seen = Set<String>()
    return exerciseGroups.flatMap(\.items).filter { seen.insert($0.lowercased()).inserted }
}()

/// Grupos que encajan con lo que ha pedido el usuario, para no mandarle al modelo
/// las 130 opciones (el on-device tiene contexto corto y se satura). Si no se
/// reconoce nada, devuelve los grupos de fuerza principales.
/// Grupo nombrado EXPLÍCITAMENTE en el texto (nil si no se menciona ninguno). A
/// diferencia de `exerciseGroups(matching:)`, no cae a un valor por defecto: sirve para
/// saber si el usuario nombró un grupo de verdad.
func namedExerciseGroup(in text: String) -> ExerciseGroup? {
    let d = text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    // El más específico primero: «isquios» debe ganar a «pierna».
    return exerciseGroups
        .filter { g in g.keywords.contains { d.contains($0.folding(options: .diacriticInsensitive, locale: .current).lowercased()) } }
        .min { $0.keywords.count > $1.keywords.count }
}

func exerciseGroups(matching description: String) -> [ExerciseGroup] {
    let d = description.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    let hits = exerciseGroups.filter { g in
        g.keywords.contains { d.contains($0.folding(options: .diacriticInsensitive, locale: .current).lowercased()) }
    }
    if !hits.isEmpty { return hits }
    // «Full body», «torso», o algo que no reconocemos → los grandes grupos de fuerza.
    let core = ["Pecho", "Espalda", "Isquiosurales y glúteo", "Cuádriceps", "Hombro", "Bíceps", "Tríceps", "Core"]
    return exerciseGroups.filter { core.contains($0.name) }
}

func searchExercises(_ query: String) -> [String] {
    let q = query.folding(options: .diacriticInsensitive, locale: .current)
        .lowercased().trimmingCharacters(in: .whitespaces)
    if q.isEmpty { return Array(exerciseCatalog.prefix(8)) }
    let matches = exerciseCatalog.filter {
        $0.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q)
            || L10n.x($0).lowercased().contains(q)
    }
    // Exact match shouldn't be suggested (already typed)
    return matches.filter { $0.caseInsensitiveCompare(query) != .orderedSame && L10n.x($0).caseInsensitiveCompare(query) != .orderedSame }
}

/// Nombre en inglés (lo que ve el usuario) → nombre de catálogo guardado (en español),
/// para que el historial de un ejercicio siga siendo el mismo. Si no es del catálogo,
/// se guarda tal cual.
func catalogName(forDisplay display: String) -> String {
    let d = display.trimmingCharacters(in: .whitespaces)
    return exerciseCatalog.first { L10n.x($0).caseInsensitiveCompare(d) == .orderedSame } ?? d
}
