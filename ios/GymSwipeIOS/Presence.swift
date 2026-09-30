import Foundation
import CoreLocation
import UIKit

/// Presencia para **Your Circle** (migración 0028): distancia y «online».
///
/// - Solo con la app ABIERTA: permiso «When In Use», nada en segundo plano.
/// - Se sube la posición y el servidor la ajusta a una cuadrícula de ~110 m antes de
///   guardarla; ningún cliente lee coordenadas, solo la distancia ya calculada.
/// - Online = latido cada minuto mientras la app está activa; al pasar a segundo plano
///   se avisa al servidor para dejar de salir online al momento.
/// - Mostrar distancia y online lo decide cada persona (`show_distance`, `show_online`).
@MainActor
final class PresenceService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PresenceService()

    @Published private(set) var authorization: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var heartbeat: Timer?
    private var lastSent: CLLocation?
    private var active = false

    var canUseLocation: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var locationDenied: Bool { authorization == .denied || authorization == .restricted }

    private override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100   // la cuadrícula del servidor es de ~110 m
    }

    /// App en primer plano: latido + ubicación (si ya hay permiso; no lo pide solo).
    func start() {
        guard BackendConfig.isConfigured, !active else { return }
        active = true
        Task { await Backend.shared.heartbeat() }
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { await Backend.shared.heartbeat() }
        }
        if canUseLocation { manager.startUpdatingLocation() }
    }

    /// App en segundo plano: deja de estar online y de seguir la ubicación.
    func stop() {
        guard active else { return }
        active = false
        heartbeat?.invalidate(); heartbeat = nil
        manager.stopUpdatingLocation()
        Task { await Backend.shared.goOffline() }
    }

    /// Lo pide Your Circle cuando la persona toca «Show distances».
    func requestPermission() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if locationDenied, let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = s
            if self.active && self.canUseLocation { self.manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 1000 else { return }
        Task { @MainActor in
            if let last = self.lastSent, last.distance(from: loc) < 100,
               loc.timestamp.timeIntervalSince(last.timestamp) < 15 * 60 { return }
            self.lastSent = loc
            await Backend.shared.updatePresenceExact(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
            // La celda gruesa (~5 km) que siguen usando los planes de entreno.
            await Backend.shared.updatePresence(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Presence] ubicación no disponible:", error.localizedDescription)
    }
}

// MARK: - Formato de distancia (lo que se PINTA)

enum CircleDistance {
    /// «80 m», «1.2 km», «12 km». El servidor ya la redondea (50 m / 100 m).
    static func label(_ meters: Int) -> String {
        if meters < 1000 { return "\(meters) m" }
        let km = Double(meters) / 1000
        let f = NumberFormatter()
        f.locale = L10n.locale
        f.maximumFractionDigits = km < 10 ? 1 : 0
        f.minimumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: km)) ?? "\(Int(km))") km"
    }
}
