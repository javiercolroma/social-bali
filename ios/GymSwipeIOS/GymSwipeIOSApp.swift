import SwiftUI
import GoogleSignIn

@main
struct GymSwipeIOSApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.auth == nil {
                    AuthView()
                } else {
                    RootView()
                }
            }
            .environmentObject(store)
            .tint(Color(hex: "5e910e"))
            // Devuelve el callback de OAuth de Google al SDK.
            .onOpenURL { url in GIDSignIn.sharedInstance.handle(url) }
            // Arranque: si ya hay sesión Supabase, trae el histórico del servidor (gateado).
            .task { store.syncSessionsFromBackend() }
        }
    }
}
