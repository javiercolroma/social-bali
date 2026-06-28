import SwiftUI
import WebKit
import CoreLocation

struct ContentView: View {
    var body: some View {
        WebAppView()
            .ignoresSafeArea()
            .background(Color("LaunchBackground"))
    }
}

struct WebAppView: UIViewRepresentable {
    func makeCoordinator() -> GeolocationBridge {
        GeolocationBridge()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // Bridge navigator.geolocation -> native CoreLocation so the real
        // device location is used instead of the in-app fallback.
        let userScript = WKUserScript(
            source: GeolocationBridge.injectedJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(userScript)
        configuration.userContentController.add(context.coordinator, name: "geo")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false

        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebDist"),
              let webDistURL = Bundle.main.url(forResource: "WebDist", withExtension: nil) else {
            webView.loadHTMLString("<html><body>Missing WebDist/index.html</body></html>", baseURL: nil)
            return webView
        }

        webView.loadFileURL(indexURL, allowingReadAccessTo: webDistURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

final class GeolocationBridge: NSObject, WKScriptMessageHandler, CLLocationManagerDelegate {
    weak var webView: WKWebView?
    private let manager = CLLocationManager()
    private var pendingKeys: [Int] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let key = body["key"] as? Int else {
            return
        }

        pendingKeys.append(key)

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            reject(code: 1, message: "Permiso denegado")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if !pendingKeys.isEmpty {
                manager.requestLocation()
            }
        case .denied, .restricted:
            reject(code: 1, message: "Permiso denegado")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }

        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        let accuracy = max(0, location.horizontalAccuracy)
        let keys = pendingKeys
        pendingKeys.removeAll()

        for key in keys {
            webView?.evaluateJavaScript("window.__geoResolve && window.__geoResolve(\(key), \(lat), \(lng), \(accuracy))")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        reject(code: 2, message: "Ubicación no disponible")
    }

    private func reject(code: Int, message: String) {
        let keys = pendingKeys
        pendingKeys.removeAll()
        for key in keys {
            webView?.evaluateJavaScript("window.__geoReject && window.__geoReject(\(key), \(code), '\(message)')")
        }
    }

    static let injectedJS = """
    (function () {
      if (!('geolocation' in navigator)) {
        try { Object.defineProperty(navigator, 'geolocation', { value: {}, configurable: true }); } catch (e) {}
      }
      var callbacks = {};
      var counter = 0;
      function request(success, error) {
        var key = ++counter;
        callbacks[key] = { success: success, error: error };
        try {
          window.webkit.messageHandlers.geo.postMessage({ key: key });
        } catch (e) {
          if (error) { error({ code: 2, message: 'bridge unavailable' }); }
          delete callbacks[key];
        }
        return key;
      }
      navigator.geolocation.getCurrentPosition = function (success, error) { request(success, error); };
      navigator.geolocation.watchPosition = function (success, error) { return request(success, error); };
      navigator.geolocation.clearWatch = function () {};
      window.__geoResolve = function (key, lat, lng, accuracy) {
        var cb = callbacks[key];
        if (!cb) { return; }
        cb.success({
          coords: {
            latitude: lat,
            longitude: lng,
            accuracy: accuracy,
            altitude: null,
            altitudeAccuracy: null,
            heading: null,
            speed: null
          },
          timestamp: Date.now()
        });
        delete callbacks[key];
      };
      window.__geoReject = function (key, code, message) {
        var cb = callbacks[key];
        if (!cb) { return; }
        if (cb.error) { cb.error({ code: code, message: message }); }
        delete callbacks[key];
      };
    })();
    """
}
