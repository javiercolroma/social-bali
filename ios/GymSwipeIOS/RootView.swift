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

    private let titles = ["Social", "Plan", "Entreno", "Ranking", "Partner"]

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $tab) {
                SocialFeedView(onOpenProfile: { profilePerson = IdString(id: $0) })
                    .tag(0).tabItem { Label("Social", systemImage: "newspaper.fill") }.toolbar(.hidden, for: .tabBar)
                PlanView(onLoaded: { tab = 2 })
                    .tag(1).tabItem { Label("Plan", systemImage: "list.bullet.clipboard") }.toolbar(.hidden, for: .tabBar)
                TrainView(onGoToPlan: { tab = 1 })
                    .tag(2).tabItem { Label("Entreno", systemImage: "dumbbell.fill") }.toolbar(.hidden, for: .tabBar)
                RankingView()
                    .tag(3).tabItem { Label("Ranking", systemImage: "globe.europe.africa.fill") }.toolbar(.hidden, for: .tabBar)
                PartnerView(onOpenChat: { chatPerson = IdString(id: $0) })
                    .tag(4).tabItem { Label("Partner", systemImage: "person.2.fill") }.toolbar(.hidden, for: .tabBar)
            }
            .onChange(of: tab) { _ in FX.selection() }

            CustomTabBar(tab: $tab)
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
                               onOpenFriends: { showNotifications = false; messagesTab = 1; showMessages = true })
                .environmentObject(store)
        }
        .fullScreenCover(item: $chatPerson) { item in
            ChatView(personId: item.id, onOpenProfile: { profilePerson = IdString(id: $0) })
                .environmentObject(store)
        }
        .sheet(item: $profilePerson) { item in
            if let person = store.person(item.id) {
                FriendProfileView(person: person).environmentObject(store)
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .environmentObject(store)
                    .navigationTitle("Perfil").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { showProfile = false } } }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.account == nil || editingAccount },
            set: { if !$0 { editingAccount = false } }
        )) {
            AccountSetupView(allowCancel: store.account != nil, onCancel: { editingAccount = false })
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FORGE LOOP").font(.caption2).fontWeight(.heavy).kerning(1.4).foregroundColor(Color(hex: "4b6211"))
                Text(titles[tab]).font(.system(size: 30, weight: .heavy)).foregroundColor(Brand.ink)
            }
            Spacer()
            headerButton(system: "envelope.fill", badge: store.unreadMessages) { FX.tap(); messagesTab = 0; showMessages = true }
            headerButton(system: "bell.fill", badge: store.unreadNotifications) { FX.tap(); showNotifications = true }
            Button { FX.tap(); showProfile = true } label: {
                MeAvatar(account: store.account, size: 44)
                    .overlay(Circle().stroke(Brand.line))
            }
            .accessibilityLabel("Perfil")
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
    @Binding var tab: Int
    private let items: [(title: String, icon: String)] = [
        ("Social", "newspaper.fill"),
        ("Plan", "list.bullet.clipboard"),
        ("Entreno", "dumbbell.fill"),
        ("Ranking", "globe.europe.africa.fill"),
        ("Partner", "person.2.fill"),
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
        return Button { tab = idx } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: active ? .heavy : .semibold))
                    .frame(width: 46, height: 30)
                    .background(active ? Brand.greenSoft.opacity(0.55) : .clear)
                    .clipShape(Capsule())
                Text(item.title).font(.system(size: 10, weight: .heavy))
            }
            .foregroundColor(active ? accent : Brand.soft)
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.18), value: tab)
        }
    }

    private func centerButton(_ idx: Int, _ item: (title: String, icon: String)) -> some View {
        let active = tab == idx
        return Button { tab = idx } label: {
            VStack(spacing: 4) {
                Image(systemName: item.icon).font(.system(size: 20, weight: .heavy))
                    .foregroundColor(active ? Color(hex: "10150a") : Brand.soft)
                    .frame(width: 50, height: 50)
                    .background(active ? Brand.green : Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(active ? Color.clear : Brand.line, lineWidth: 1))
                    .shadow(color: active ? Brand.green.opacity(0.4) : .black.opacity(0.06), radius: active ? 8 : 4, y: 3)
                Text(item.title).font(.system(size: 10, weight: .heavy))
                    .foregroundColor(active ? accent : Brand.soft)
            }
            .frame(maxWidth: .infinity)
            .offset(y: -8)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: tab)
        }
    }
}
