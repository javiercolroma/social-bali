import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var status = "Approximate location"
    /// Nombre legible y aproximado (p. ej. "Chamberí, Madrid") de la última ubicación.
    @Published var placeName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        status = "Finding your location…"
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: status = "Location permission denied"
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in
            if s == .authorizedWhenInUse || s == .authorizedAlways {
                manager.requestLocation()
            } else if s == .denied || s == .restricted {
                self.status = "Location permission denied"
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Presencia para el mapa de calor: solo la CELDA (~5 km), nunca la posición exacta.
        if let c = locations.last?.coordinate {
            Task { await Backend.shared.updatePresence(lat: c.latitude, lon: c.longitude) }
        }
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.coordinate = loc.coordinate
            self.status = "Your approximate area"
            self.resolvePlaceName(for: loc)
        }
    }

    /// Geocodificación inversa → zona aproximada (barrio + ciudad), sin calle ni número.
    private func resolvePlaceName(for loc: CLLocation) {
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(loc, preferredLocale: L10n.locale) { [weak self] marks, _ in
            guard let self, let m = marks?.first else { return }
            let area = m.subLocality ?? m.locality ?? m.subAdministrativeArea
            let city = m.locality ?? m.subAdministrativeArea ?? m.administrativeArea
            let parts = [area, city].compactMap { $0 }
            // Quitar duplicados consecutivos (p. ej. barrio == ciudad).
            var out: [String] = []
            for p in parts where out.last != p { out.append(p) }
            Task { @MainActor in
                let name = out.joined(separator: ", ")
                if !name.isEmpty { self.placeName = name }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.status = "Location unavailable" }
    }
}
