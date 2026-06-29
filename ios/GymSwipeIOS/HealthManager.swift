import Foundation
import HealthKit

/// Conexión con la app Salud (HealthKit). De momento lee la frecuencia cardíaca
/// para registrarla durante el entrenamiento (BPM en vivo + media/máx por sesión).
///
/// Nota: el iPhone no mide pulsaciones por sí solo; los datos llegan de un Apple
/// Watch (u otra fuente) que escribe en Salud. En el simulador no hay pulso en
/// vivo salvo que añadas muestras manualmente en la app Salud.
@MainActor
final class HealthManager: ObservableObject {
    static let shared = HealthManager()

    private let healthStore = HKHealthStore()
    private let hrType = HKQuantityType(.heartRate)
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    /// HealthKit disponible en este dispositivo.
    let isAvailable = HKHealthStore.isHealthDataAvailable()

    /// El usuario ha conectado Salud (persistido). Para lecturas, HealthKit no
    /// revela si el permiso está concedido, así que usamos esta marca tras pedirlo.
    @Published private(set) var connected: Bool
    @Published var liveBPM: Int?
    @Published var sessionAvg: Int?
    @Published var sessionMax: Int?

    private var query: HKAnchoredObjectQuery?
    private var samples: [Double] = []
    private let connectedKey = "healthConnected"

    private init() {
        connected = UserDefaults.standard.bool(forKey: connectedKey)
    }

    /// Pide permiso de lectura de frecuencia cardíaca. Devuelve true si no hubo error.
    @discardableResult
    func connect() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [hrType])
            connected = true
            UserDefaults.standard.set(true, forKey: connectedKey)
            return true
        } catch {
            return false
        }
    }

    /// Empieza a recoger frecuencia cardíaca desde ahora (solo si está conectado).
    func startSession() {
        guard isAvailable, connected else { return }
        stopQuery()
        samples = []
        liveBPM = nil; sessionAvg = nil; sessionMax = nil

        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
        let q = HKAnchoredObjectQuery(type: hrType, predicate: predicate, anchor: nil,
                                      limit: HKObjectQueryNoLimit) { [weak self] _, newSamples, _, _, _ in
            self?.ingest(newSamples)
        }
        q.updateHandler = { [weak self] _, newSamples, _, _, _ in
            self?.ingest(newSamples)
        }
        healthStore.execute(q)
        query = q
    }

    /// Para la recogida y devuelve la media/máx de la sesión.
    @discardableResult
    func endSession() -> (avg: Int?, max: Int?) {
        stopQuery()
        return (sessionAvg, sessionMax)
    }

    // MARK: - Privado

    private nonisolated func ingest(_ newSamples: [HKSample]?) {
        guard let qs = newSamples as? [HKQuantitySample], !qs.isEmpty else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let values = qs.map { $0.quantity.doubleValue(for: unit) }
        // HealthKit no garantiza orden: la muestra "actual" es la más reciente por fecha.
        let latest = qs.max(by: { $0.endDate < $1.endDate })?.quantity.doubleValue(for: unit)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.samples.append(contentsOf: values)
            if let latest { self.liveBPM = Int(latest.rounded()) }
            if !self.samples.isEmpty {
                self.sessionAvg = Int((self.samples.reduce(0, +) / Double(self.samples.count)).rounded())
                self.sessionMax = Int((self.samples.max() ?? 0).rounded())
            }
        }
    }

    private func stopQuery() {
        if let q = query { healthStore.stop(q); query = nil }
    }
}
