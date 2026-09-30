import Foundation
import UserNotifications
import UIKit

/// Notificaciones de Forge Loop.
/// - LOCAL (funciona ya, sin servidor): recordatorio de "racha en peligro" — la racha se rompe
///   al pasar más de 3 días sin entrenar, así que se programa un aviso 3 días después del
///   último entreno; cada entreno nuevo lo re-programa (y así nunca suena si sigues activo).
/// - PUSH (scaffolding): registra el token APNs en `device_tokens`; el envío server-side
///   (mensajes/follows/likes) llegará cuando haya clave APNs del Apple Developer account.
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private let streakId = "streak-reminder"

    /// Pide permiso (el sistema solo pregunta la primera vez) y programa el recordatorio.
    /// Se llama al GUARDAR un entreno: el momento de máxima buena voluntad del usuario.
    func afterWorkoutSaved(streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            Task { @MainActor in
                UIApplication.shared.registerForRemoteNotifications()   // token APNs (push social, futuro)
                self.scheduleStreakReminder(streak: streak)
            }
        }
    }

    /// Re-programa el aviso de racha: uno solo, 3 días después del último entreno, a las 18h.
    func scheduleStreakReminder(streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakId])
        guard streak > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "🔥 Your \(streak)-day streak is at risk"
        content.body = "You haven't trained in 3 days. One workout today saves it."
        content.sound = .default
        // 3 días desde ahora, redondeado a las 18:00 de ese día (hora amable).
        var fire = Date().addingTimeInterval(3 * 24 * 3600)
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: fire)
        comps.hour = 18; comps.minute = 0
        if let at6pm = Calendar.current.date(from: comps), at6pm > Date() { fire = at6pm }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, fire.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: streakId, content: content, trigger: trigger))
    }

    /// Al cerrar sesión / borrar cuenta: cancela recordatorios pendientes.
    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Token APNs recibido del sistema → se guarda en el servidor para el push social futuro.
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
        // Sin entitlement de push (aún no configurado) esto es esperable; el recordatorio local funciona igual.
        print("[Push] registro APNs falló (esperable sin entitlement):", error.localizedDescription)
    }
}
