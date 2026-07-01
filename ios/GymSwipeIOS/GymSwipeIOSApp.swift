import SwiftUI
import GoogleSignIn

@main
struct GymSwipeIOSApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

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
            // Arranque: si ya hay sesión Supabase, trae el histórico y el ranking real (gateado).
            // Y si hay sesión pero no cuenta local, rehidrata el perfil (evita repetir onboarding).
            .task {
                if store.auth != nil && store.account == nil { store.hydrateAccountFromBackend() }
                store.syncSessionsFromBackend(); store.loadLeaderboard()
                store.loadFollowing(); store.loadConversations()
            }
            // Al volver a primer plano: re-sincroniza (SUBE cualquier entreno que no subiera en su
            // momento) y refresca no leídos. Así el muro del otro ve TODOS los entrenos.
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    store.syncSessionsFromBackend(); store.loadConversations()
                }
            }
        }
    }
}
