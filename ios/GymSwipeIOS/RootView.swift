import SwiftUI

struct IdString: Identifiable { let id: String }

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab = 0
    @State private var showMessages = false
    @State private var messagesTab = 0
    @State private var showNotifications = false
    @State private var editingAccount = false
    @State private var chatPerson: IdString?
    @State private var profilePerson: IdString?
    @State private var showProfile = false

    private let titles = ["Social", "Plan", "Entreno", "Comunidad", "Actividad"]

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                screen(0) { SocialFeedView(onOpenProfile: { profilePerson = IdString(id: $0) },
                                           onOpenMyProfile: { showProfile = true }) }
                screen(1) { PlanView(onLoaded: { tab = 2 }) }
                screen(2) { TrainView(onGoToPlan: { tab = 1 }) }
                screen(3) { CommunityView(onOpenChat: { chatPerson = IdString(id: $0) }) }
                screen(4) { ActivityView() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: tab) { _ in FX.selection() }

            CustomTabBar(tab: tab, onSelect: { tab = $0 }).id(tab)
        }
        .background(Brand.bg.ignoresSafeArea())
        .sheet(isPresented: $showMessages) {
            MessagesSheet(initialTab: messagesTab,
                          onOpenChat: { showMessages = false; chatPerson = IdString(id: $0) },
                          onOpenProfile: { profilePerson = IdString(id: $0) },
                          onEditAccount: { editingAccount = true })
                .environmentObject(store)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsSheet(onOpenChat: { showNotifications = false; chatPerson = IdString(id: $0) },
                               onOpenFriends: { showNotifications = false; messagesTab = 0; showMessages = true })
                .environmentObject(store)
        }
        .overlay {
            if let item = chatPerson {
                ChatView(personId: item.id,
                         onOpenProfile: { profilePerson = IdString(id: $0) },
                         onClose: { chatPerson = nil })
                    .environmentObject(store)
                    .transition(.move(edge: .trailing))
                    .zIndex(5)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: chatPerson?.id)
        .sheet(item: $profilePerson) { item in
            if let person = store.person(item.id) {
                FriendProfileView(person: person).environmentObject(store)
            }
        }
        .sheet(isPresented: $showProfile) {
            MeProfileView().environmentObject(store)
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.account == nil || editingAccount },
            set: { if !$0 { editingAccount = false } }
        )) {
            // Usuario nuevo: acompañamiento cálido paso a paso. Edición: el formulario simple de siempre.
            if store.account == nil {
                OnboardingView().environmentObject(store)
            } else {
                AccountSetupView(allowCancel: true, onCancel: { editingAccount = false })
                    .environmentObject(store)
            }
        }
    }

    @ViewBuilder
    private func screen<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(tab == index ? 1 : 0)
            .allowsHitTesting(tab == index)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { FX.tap(); showProfile = true } label: {
                MeAvatar(account: store.account, size: 44)
                    .overlay(Circle().stroke(Brand.line))
                    .overlay(alignment: .bottomTrailing) {
                        // Gym Score con el color de la división (Hierro → Maestro).
                        ScoreBadge(score: store.gymScore.total, avatarSize: 44)
                    }
            }
            .accessibilityLabel("Perfil · Gym Score \(store.gymScore.total)")
            VStack(alignment: .leading, spacing: 2) {
                Text("FORGE LOOP").font(.caption2).fontWeight(.heavy).kerning(1.4).foregroundColor(Color(hex: "4b6211"))
                Text(titles[tab]).font(.system(size: 30, weight: .heavy)).foregroundColor(Brand.ink)
            }
            Spacer()
            headerButton(system: "envelope.fill", badge: store.unreadMessages) { FX.tap(); messagesTab = 1; showMessages = true }
            headerButton(system: "bell.fill", badge: store.unreadNotifications) { FX.tap(); showNotifications = true }
}
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Brand.bg)
    }

    private func headerButton(system: String, badge: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: system)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Brand.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
                        .padding(.horizontal, 5).frame(minWidth: 18, minHeight: 18)
                        .background(Brand.red).clipShape(Capsule())
                        .offset(x: 5, y: -5)
                }
            }
        }
    }
}

struct CustomTabBar: View {
    // Se pasa el VALOR (no un @Binding): así el resaltado SIEMPRE se re-renderiza al
    // cambiar de pestaña. Con solo un @Binding, SwiftUI podía saltarse el re-render y el
    // resaltado se quedaba pegado en Social.
    let tab: Int
    var onSelect: (Int) -> Void
    private let items: [(title: String, icon: String)] = [
        ("Social", "newspaper.fill"),
        ("Plan", "list.bullet.clipboard"),
        ("Entreno", "dumbbell.fill"),
        ("Comunidad", "person.3.fill"),
        ("Actividad", "chart.bar.fill"),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                if idx == 2 { centerButton(idx, item) } else { tabButton(idx, item) }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, max(8, safeBottom))
        .background(Brand.bg)
    }

    private var safeBottom: CGFloat {
        (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?
            .windows.first?.safeAreaInsets.bottom) ?? 0
    }

    private let accent = Color(hex: "5e910e")

    private func tabButton(_ idx: Int, _ item: (title: String, icon: String)) -> some View {
        let active = tab == idx
        return Button { onSelect(idx) } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: active ? .heavy : .semibold))
                    .frame(width: 46, height: 30)
                    .background(active ? Brand.greenSoft : .clear)
                    .clipShape(Capsule())
                Text(item.title).font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(active ? accent : Brand.soft)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func centerButton(_ idx: Int, _ item: (title: String, icon: String)) -> some View {
        let active = tab == idx
        return Button { onSelect(idx) } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon).font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(active ? Color(hex: "10150a") : Brand.soft)
                    .frame(width: 50, height: 50)
                    .background(active ? Brand.green : Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(active ? Color.clear : Brand.line, lineWidth: 1))
                    .shadow(color: active ? Brand.green.opacity(0.4) : .black.opacity(0.06), radius: active ? 8 : 4, y: 3)
                Text(item.title).font(.system(size: 10, weight: .heavy)).foregroundStyle(active ? accent : Brand.soft)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
