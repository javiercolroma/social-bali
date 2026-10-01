import SwiftUI
import GoogleSignIn

@main
struct GymSwipeIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate   // token APNs
    @StateObject private var store = AppStore()

    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if store.auth == nil {
                    AuthView()
                } else {
                    RootView()
                }
            }
            // Vía NATIVA de SwiftUI: los Text localizan con el locale del entorno.
            .environment(\.locale, L10n.locale)
            .environmentObject(store)
            // Arranque con el logo dibujándose.
            .overlay {
                if showSplash {
                    LaunchSplash { withAnimation(.easeOut(duration: 0.35)) { showSplash = false } }
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            // La paleta de Brand es CLARA fija (fondos blancos, tinta casi negra) y los
            // fondos se escriben a mano con `Color.white`. En un iPhone en modo oscuro,
            // todo lo que NO lleva color explícito (el texto que escribes en un TextField,
            // sobre todo) se volvía BLANCO SOBRE BLANCO: invisible. Hasta que exista un
            // tema oscuro de verdad, la app se declara clara y se ve igual en ambos modos.
            .preferredColorScheme(.light)
            .tint(Brand.bronze)
            // Deep links: invitaciones balicircle://user/<usuario> + callback OAuth de Google.
            .onOpenURL { url in
                if url.scheme == "balicircle" {
                    // balicircle://user/<handle> → abre ese perfil (la "solicitud de amistad" de la invitación)
                    let parts = url.absoluteString.replacingOccurrences(of: "balicircle://", with: "").split(separator: "/")
                    if parts.first == "user", parts.count > 1 {
                        store.openProfileByHandle(String(parts[1]).removingPercentEncoding ?? String(parts[1]))
                    }
                    return
                }
                GIDSignIn.sharedInstance.handle(url)
            }
            // Arranque. Sesión local SIN sesión en el servidor (p. ej. un login que el servidor
            // rechazó): se cierra, para ver el login en vez de pantallas que no cargan.
            .task {
                guard store.auth != nil else { return }
                await store.validateBackendSession()
                guard store.auth != nil else { return }
                if store.account == nil { store.hydrateAccountFromBackend() }
                Task { await Backend.shared.touchPresence() }
                PresenceService.shared.start()   // online + distancia de Your Circle (solo con la app abierta)
                store.loadConversations()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    store.loadConversations()
                    if store.auth != nil { PresenceService.shared.start() }
                } else if phase == .background {
                    PresenceService.shared.stop()   // deja de salir online al momento
                }
            }
        }
    }
}
