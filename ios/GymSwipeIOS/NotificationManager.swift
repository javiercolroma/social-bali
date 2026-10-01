import Foundation
import UserNotifications
import UIKit

/// Notificaciones de Bali Circle: solo PUSH (solicitudes de conexión y mensajes, que envía
/// el servidor). Aquí se pide permiso y se registra el token APNs en `device_tokens`.
/// El recordatorio local de «racha en peligro» se quitó con todo lo de entrenamiento.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    /// Pide permiso (el sistema solo pregunta la primera vez) y registra el token APNs.
    /// Se llama con la cuenta ya creada: antes se pedía al guardar un entreno.
    func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    /// Al cerrar sesión / borrar cuenta: cancela notificaciones locales pendientes (si las hubiera
    /// de versiones anteriores, como el aviso de racha).
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Token APNs recibido del sistema → se guarda en el servidor para los push.
    func didRegister(tokenData: Data) {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        Task { try? await Backend.shared.upsertDeviceToken(token) }
    }
}

/// Puente UIKit: recibe el token APNs (SwiftUI no expone este callback).
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in NotificationManager.shared.didRegister(tokenData: deviceToken) }
    }
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Sin entitlement de push (aún no configurado) esto es esperable.
        print("[Push] registro APNs falló (esperable sin entitlement):", error.localizedDescription)
    }
}
