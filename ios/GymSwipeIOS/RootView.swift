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

    private let titles = ["Entreno", "Plan", "Ranking", "Social", "Partner"]

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $tab) {
                TrainView(onGoToPlan: { tab = 1 }).tag(0).tabItem { Label("Entreno", systemImage: "dumbbell.fill") }
                PlanView(onLoaded: { tab = 0 }).tag(1).tabItem { Label("Plan", systemImage: "list.bullet.clipboard") }
                RankingView().tag(2).tabItem { Label("Ranking", systemImage: "globe.europe.africa.fill") }
                SocialFeedView(onOpenProfile: { profilePerson = IdString(id: $0) }).tag(3).tabItem { Label("Social", systemImage: "newspaper.fill") }
                PartnerView(onOpenChat: { chatPerson = IdString(id: $0) }).tag(4).tabItem { Label("Partner", systemImage: "person.2.fill") }
            }
            .onChange(of: tab) { _ in FX.selection() }
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
