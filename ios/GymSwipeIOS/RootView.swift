import SwiftUI

struct IdString: Identifiable { let id: String }

/// Bali Circle: tres pestañas — Circle · Chats · Profile. Nada de entrenos ni mascota.
struct RootView: View {
    @EnvironmentObject var store: AppStore
    enum Tab: Hashable { case circle, chats, profile }
    @State private var tab: Tab = .circle
    /// Pila de navegación de Chats: el chat abierto (deslizar desde el borde para volver).
    @State private var chatPath: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                screen(.circle) { YourCircleView() }
                screen(.chats) { ChatsView(asTab: true, path: $chatPath) }
                screen(.profile) { MeProfileView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: tab) { _ in FX.selection() }

            // .id(tab): obliga a redibujar la barra al cambiar de pestaña. Sin él, SwiftUI a
            // veces se salta el refresco y el resaltado se queda en la primera pestaña.
            // Dentro de un chat no hay barra de pestañas (como en WhatsApp).
            if !(tab == .chats && !chatPath.isEmpty) {
                ClubTabBar(tab: tab, chatsBadge: store.unreadMessages) { tab = $0 }
                    .id(tab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Brand.bg.ignoresSafeArea())
        // «Message» / aceptar una conexión: abre el chat desde cualquier pantalla.
        .onReceive(store.$openChatWith.compactMap { $0 }) { pid in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                tab = .chats
                chatPath = [pid]
                // Se limpia DESPUÉS: las hojas abiertas (perfil, solicitudes) se cierran al VER el valor.
                store.openChatWith = nil
            }
        }
        .animation(.easeInOut(duration: 0.25), value: chatPath.isEmpty)
        // Aviso breve (toast).
        .overlay(alignment: .bottom) {
            if let msg = store.flashMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .heavy)).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color(hex: "16240b").opacity(0.94)).clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 24).padding(.bottom, 96)
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { store.flashMessage = nil } }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.flashMessage)
        // Cuenta nueva: el registro del club.
        .fullScreenCover(isPresented: Binding(
            get: { store.auth != nil && store.account == nil && !store.checkingProfile },
            set: { _ in }
        )) {
            OnboardingView().environmentObject(store)
        }
        // Mientras comprobamos si ya tienes perfil en el servidor (para no repetir el registro).
        .overlay {
            if store.checkingProfile {
                ZStack {
                    Brand.bg.ignoresSafeArea()
                    ProgressView().scaleEffect(1.3)
                }
            }
        }
    }

    @ViewBuilder
    private func screen<Content: View>(_ t: Tab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(tab == t ? 1 : 0)
            .allowsHitTesting(tab == t)
    }
}

struct ClubTabBar: View {
    let tab: RootView.Tab
    let chatsBadge: Int
    var onSelect: (RootView.Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            item(.circle, "Circle", "circle.grid.2x2.fill", badge: 0)
            item(.chats, "Chats", "bubble.left.and.bubble.right.fill", badge: chatsBadge)
            item(.profile, "Profile", "person.crop.circle.fill", badge: 0)
        }
        .padding(.top, 2)
        .padding(.bottom, max(8, safeBottom))
        .background(Brand.bg.overlay(Divider(), alignment: .top))
    }

    private var safeBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.bottom ?? 0
    }

    private func item(_ t: RootView.Tab, _ title: LocalizedStringKey, _ icon: String, badge: Int) -> some View {
        let active = tab == t
        return Button { onSelect(t) } label: {
            VStack(spacing: 4) {
                // Rayita arriba en la pestaña activa: se ve aunque el color cambie poco.
                Capsule().fill(active ? Brand.ink : Color.clear).frame(width: 18, height: 3).padding(.bottom, 2)
                Image(systemName: active ? icon : icon.replacingOccurrences(of: ".fill", with: ""))
                    .font(.system(size: 20, weight: active ? .semibold : .regular))
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text("\(badge)").font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                                .padding(.horizontal, 4).frame(minWidth: 16, minHeight: 16)
                                .background(Brand.red).clipShape(Capsule()).offset(x: 10, y: -6)
                        }
                    }
                Text(title).font(.system(size: 11, weight: active ? .bold : .medium))
            }
            .foregroundColor(active ? Brand.ink : Brand.soft.opacity(0.8))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
