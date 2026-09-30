import UIKit

/// Configuración del inicio de sesión con Google.
///
/// ─── CÓMO ACTIVARLO (≈5 min) ────────────────────────────────────────────────
/// 1. Entra en https://console.cloud.google.com/apis/credentials (crea un proyecto si no tienes).
/// 2. "Crear credenciales" → "ID de cliente de OAuth" → tipo de aplicación **iOS**.
///      • ID del paquete (Bundle ID): com.javiercolroma.balicircle
/// 3. Copia el **ID de cliente** (termina en `.apps.googleusercontent.com`) y pégalo en
///    `clientID` aquí abajo.
/// 4. Copia el **Esquema de URL de iOS** (es el client ID al revés, empieza por
///    `com.googleusercontent.apps.…`) y pégalo en `ios/project.yml`, sustituyendo el
///    marcador `GOOGLE_REVERSED_CLIENT_ID`. Luego ejecuta `npm run ios:generate`.
///
/// Mientras `clientID` esté vacío, el botón de Google muestra una ayuda en vez de fallar.
/// (El login con Apple y con email funcionan sin nada de esto.)
enum GoogleAuth {
    /// Pega aquí tu iOS OAuth client ID de Google Cloud.
    static let clientID = ""   // pendiente: cliente OAuth nuevo para com.javiercolroma.balicircle

    /// ¿Están puestas las credenciales? Si no, el botón de Google queda desactivado con ayuda.
    static var isConfigured: Bool { !clientID.isEmpty }
}

extension UIApplication {
    /// View controller raíz de la escena activa (para presentar la hoja de Google Sign-In desde SwiftUI).
    var activeRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
