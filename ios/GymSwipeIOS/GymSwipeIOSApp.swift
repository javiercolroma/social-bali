import SwiftUI
import GoogleSignIn

@main
struct GymSwipeIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate   // token APNs
    @StateObject private var store = AppStore()

    init() { L10n.bootstrap() }   // idioma forzado (si lo hay) desde el primer frame
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
            .id(store.languageToken)   // cambiar idioma en Ajustes reconstruye la UI al momento
            // Vía NATIVA de SwiftUI: los Text localizan con el locale del entorno.
            .environment(\.locale, L10n.locale)
            .environmentObject(store)
            // La paleta de Brand es CLARA fija (fondos blancos, tinta casi negra) y los
            // fondos se escriben a mano con `Color.white`. En un iPhone en modo oscuro,
            // todo lo que NO lleva color explícito (el texto que escribes en un TextField,
            // sobre todo) se volvía BLANCO SOBRE BLANCO: invisible. Hasta que exista un
            // tema oscuro de verdad, la app se declara clara y se ve igual en ambos modos.
            .preferredColorScheme(.light)
            .tint(Color(hex: "5e910e"))
            // Deep links: invitaciones forgeloop://user/<usuario> + callback OAuth de Google.
            .onOpenURL { url in
                if url.scheme == "forgeloop" {
                    // forgeloop://user/<handle> → abre ese perfil (la "solicitud de amistad" de la invitación)
                    let parts = url.absoluteString.replacingOccurrences(of: "forgeloop://", with: "").split(separator: "/")
                    if parts.first == "user", parts.count > 1 {
                        store.openProfileByHandle(String(parts[1]).removingPercentEncoding ?? String(parts[1]))
                    }
                    return
                }
                GIDSignIn.sharedInstance.handle(url)
            }
            // Arranque: si ya hay sesión Supabase, trae el histórico y el ranking real (gateado).
            // Y si hay sesión pero no cuenta local, rehidrata el perfil (evita repetir onboarding).
            .task {
                if store.auth != nil && store.account == nil { store.hydrateAccountFromBackend() }
                store.syncSessionsFromBackend(); store.syncWorkoutsFromBackend(); store.loadLeaderboard()
                Task { await Backend.shared.touchPresence() }   // cuenta como "activo" (30 días)
                store.loadFollowing(); store.loadConversations(); store.loadConnections()
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
