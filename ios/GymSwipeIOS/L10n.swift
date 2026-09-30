import Foundation

/// La app tiene UN solo idioma: inglés. Muchas claves históricas de la UI siguen siendo
/// literales en español: `en.lproj/Localizable.strings` las mapea a inglés (es la única
/// localización del bundle, así que se ve en inglés sea cual sea el idioma del iPhone).
/// Los nombres de ejercicios, plantillas y grupos son DATOS persistidos en español:
/// `L10n.x(_:)` los muestra en inglés (los datos guardados no cambian).
enum L10n {

    static let lang = "en"

    /// Nombre del idioma para instruir a la IA ("responde en …").
    static let aiLanguage = "inglés (English)"

    /// Traduce un nombre de ejercicio/plantilla/grupo si está en el catálogo; si no
    /// (nombre puesto por el usuario), lo devuelve tal cual.
    static func x(_ name: String) -> String {
        table[norm(name)] ?? name
    }

    private static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    /// Locale fijo en inglés (fechas, números, `Text` del entorno).
    static let locale = Locale(identifier: "en")

    /// Traduce un literal de UI (clave histórica en español) a inglés, para los casos en
    /// que NO se puede usar `Text(LocalizedStringKey)`: texto que hay que manipular como
    /// String. `Text(String)` no localiza.
    static func t(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    /// clave (es, normalizada, sin tildes) → nombre en inglés
    private static let table: [String: String] = [
        // Grupos / plantillas
        "pecho": "Chest",
        "espalda": "Back",
        "pierna": "Legs",
        "hombro": "Shoulders",
        "brazo": "Arms",
        "abdomen": "Abs",
        "full body": "Full body",
        "empuje": "Push",
        "tiron": "Pull",
        "otros": "Others",
        "core": "Core",
        "gluteo": "Glutes",
        "mi entreno": "My workout",
        "mis entrenos": "My workouts",
        "por defecto": "Default",
        "compartidos": "Shared",
        "entreno": "Workout",
        // Pecho
        "press banca": "Bench press",
        "press inclinado con mancuernas": "Incline dumbbell press",
        "aperturas en polea": "Cable fly",
        "aperturas": "Fly",
        "fondos en paralelas": "Parallel-bar dips",
        "fondos": "Dips",
        "fondos en banco": "Bench dips",
        "fondos de triceps en banco": "Bench triceps dips",
        "press de pecho en maquina": "Machine chest press",
        "flexiones": "Push-ups",
        // Espalda
        "dominadas": "Pull-ups",
        "remo con barra": "Barbell row",
        "jalon al pecho": "Lat pulldown",
        "remo con mancuerna": "Dumbbell row",
        "remo en polea": "Cable row",
        "face pull": "Face pull",
        // Pierna
        "sentadilla": "Squat",
        "sentadilla trasera": "Back squat",
        "sentadilla bulgara": "Bulgarian split squat",
        "prensa de piernas": "Leg press",
        "peso muerto rumano": "Romanian deadlift",
        "peso muerto": "Deadlift",
        "curl femoral tumbado": "Lying leg curl",
        "curl femoral": "Leg curl",
        "extension de cuadriceps": "Leg extension",
        "elevacion de gemelos": "Calf raise",
        "zancadas": "Lunges",
        "hip thrust": "Hip thrust",
        // Hombro
        "press militar": "Overhead press",
        "elevaciones laterales": "Lateral raises",
        "press arnold": "Arnold press",
        "pajaros (deltoide posterior)": "Rear-delt fly",
        "pajaros": "Rear-delt fly",
        "elevaciones frontales": "Front raises",
        // Brazo
        "curl de biceps con barra": "Barbell biceps curl",
        "curl con barra": "Barbell curl",
        "curl martillo": "Hammer curl",
        "curl inclinado": "Incline curl",
        "curl predicador": "Preacher curl",
        "press frances": "Skull crushers",
        "extension de triceps en polea": "Triceps pushdown",
        // Core
        "plancha": "Plank",
        "crunch": "Crunch",
        "giro ruso": "Russian twist",
        "elevacion de piernas": "Leg raises",
        // Resto del catálogo (Exercises.swift)
        "isquiosurales y gluteo": "Hamstrings & glutes",
        "cuadriceps": "Quads",
        "gemelo": "Calves",
        "aductores y abductores": "Adductors & abductors",
        "biceps": "Biceps",
        "triceps": "Triceps",
        "hibrido y funcional": "Hybrid & functional",
        "calistenia": "Calisthenics",
        "cardio": "Cardio",
        "press banca con mancuernas": "Dumbbell bench press",
        "press inclinado con barra": "Incline barbell press",
        "press declinado": "Decline press",
        "aperturas con mancuernas": "Dumbbell fly",
        "pullover": "Pullover",
        "dominadas lastradas": "Weighted pull-ups",
        "jalon agarre cerrado": "Close-grip pulldown",
        "remo en polea baja": "Seated cable row",
        "remo en punta (t-bar)": "T-bar row",
        "remo pendlay": "Pendlay row",
        "peso muerto sumo": "Sumo deadlift",
        "encogimientos de trapecio": "Shrugs",
        "hiperextensiones": "Back extensions",
        "peso muerto rumano con mancuernas": "Dumbbell Romanian deadlift",
        "peso muerto a una pierna": "Single-leg deadlift",
        "peso muerto piernas rigidas": "Stiff-leg deadlift",
        "buenos dias (good morning)": "Good morning",
        "curl femoral sentado": "Seated leg curl",
        "curl femoral de pie": "Standing leg curl",
        "curl nordico": "Nordic curl",
        "glute-ham raise": "Glute-ham raise",
        "puente de gluteo": "Glute bridge",
        "patada de gluteo en polea": "Cable glute kickback",
        "abduccion de cadera en maquina": "Machine hip abduction",
        "zancada inversa": "Reverse lunge",
        "buenos dias con barra": "Barbell good morning",
        "curl femoral con fitball": "Stability-ball leg curl",
        "sled pull": "Sled pull",
        "sentadilla frontal": "Front squat",
        "sentadilla goblet": "Goblet squat",
        "hack squat": "Hack squat",
        "zancadas caminando": "Walking lunges",
        "step up": "Step-up",
        "sentadilla sissy": "Sissy squat",
        "prensa a una pierna": "Single-leg press",
        "pistol squat": "Pistol squat",
        "gemelo sentado": "Seated calf raise",
        "elevacion de gemelos en prensa": "Leg-press calf raise",
        "salto a la comba": "Jump rope",
        "abductores": "Hip abduction",
        "aductores": "Hip adduction",
        "zancada lateral": "Lateral lunge",
        "sentadilla sumo": "Sumo squat",
        "press militar con mancuernas": "Dumbbell shoulder press",
        "remo al menton": "Upright row",
        "elevaciones laterales en polea": "Cable lateral raises",
        "press tras nuca": "Behind-the-neck press",
        "curl de biceps con mancuernas": "Dumbbell biceps curl",
        "curl en polea": "Cable curl",
        "curl concentrado": "Concentration curl",
        "curl arana": "Spider curl",
        "patada de triceps": "Triceps kickback",
        "extension de triceps sobre la cabeza": "Overhead triceps extension",
        "press cerrado": "Close-grip bench press",
        "extension de triceps con cuerda": "Rope triceps extension",
        "plancha lateral": "Side plank",
        "crunch en polea": "Cable crunch",
        "elevacion de piernas colgado": "Hanging leg raise",
        "rueda abdominal": "Ab wheel rollout",
        "russian twist": "Russian twist",
        "hollow hold": "Hollow hold",
        "mountain climbers": "Mountain climbers",
        "dead bug": "Dead bug",
        "pallof press": "Pallof press",
        "elevacion de piernas tumbado": "Lying leg raise",
        "thruster": "Thruster",
        "clean (cargada)": "Clean",
        "power clean": "Power clean",
        "hang clean": "Hang clean",
        "snatch (arrancada)": "Snatch",
        "clean and jerk": "Clean and jerk",
        "wall ball": "Wall ball",
        "box jump": "Box jump",
        "burpee": "Burpee",
        "kettlebell swing": "Kettlebell swing",
        "turkish get-up": "Turkish get-up",
        "devil press": "Devil press",
        "sled push (empuje de trineo)": "Sled push",
        "farmer carry (paseo del granjero)": "Farmer carry",
        "battle ropes": "Battle ropes",
        "slam ball": "Slam ball",
        "thruster con mancuernas": "Dumbbell thruster",
        "man maker": "Man maker",
        "wall walk": "Wall walk",
        "muscle up": "Muscle-up",
        "fondos en anillas": "Ring dips",
        "l-sit": "L-sit",
        "pino (handstand)": "Handstand",
        "flexion en pino": "Handstand push-up",
        "carrera continua": "Steady run",
        "cinta de correr": "Treadmill",
        "sprints": "Sprints",
        "remo (rower)": "Rowing machine",
        "assault bike": "Assault bike",
        "bici estatica": "Stationary bike",
        "spinning": "Spinning",
        "eliptica": "Elliptical",
        "comba (saltar a la cuerda)": "Jump rope",
        "double unders": "Double unders",
        "natacion": "Swimming",
        "escaladora (stairmaster)": "Stair climber",
        "caminata inclinada": "Incline walk",
        "sprint en cuesta": "Hill sprints",
    ]
}
