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
    @State private var activeTour: Int?   // sección cuyo tutorial se está mostrando
    @State private var tourTarget: String?   // componente resaltado en el paso actual del tour

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
            .onChange(of: tab) { t in FX.selection(); maybeShowTour(t) }

            CustomTabBar(tab: tab, onSelect: { tab = $0 }).id(tab)
        }
        .background(Brand.bg.ignoresSafeArea())
        .onAppear { maybeShowTour(tab) }
        // Tras el onboarding (la cuenta pasa a existir), muestra el tour de Social.
        .onChange(of: store.account == nil) { isNil in if !isNil { maybeShowTour(tab) } }
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
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            GeometryReader { geo in
                if let s = activeTour {
                    let rect: CGRect? = tourTarget.flatMap { id in anchors[id].map { geo[$0] } }
                    ZStack {
                        // Velo con foco (spotlight) sobre el componente a usar.
                        CoachDim(target: rect)
                        if let r = rect {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Brand.green, lineWidth: 3)
                                .frame(width: r.width + 16, height: r.height + 16)
                                .position(x: r.midX, y: r.midY)
                                .shadow(color: Brand.green.opacity(0.7), radius: 9)
                                .allowsHitTesting(false)
                        }
                        CoachTour(section: s, onFinish: {
                            store.markTourSeen("tour-\(s)")
                            tourTarget = nil
                            activeTour = nil
                        }, onStep: { st in
                            // En Comunidad, el tour lleva al usuario a Partner mientras se lo explica.
                            if s == 3 { withAnimation(.easeInOut(duration: 0.3)) { store.communitySection = st >= 1 ? 1 : 0 } }
                        }, onTarget: { t in
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { tourTarget = t }
                        })
                        .environmentObject(store)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.16), value: activeTour)
        .overlay {
            // Ascenso de liga primero, luego hitos de racha, récords y logros.
            if let tier = store.leaguePromoted {
                LeaguePromotionCelebration(tier: tier, onDismiss: { store.leaguePromoted = nil })
                    .environmentObject(store)
                    .transition(.opacity)
                    .zIndex(12)
            } else if let days = store.streakCelebration {
                StreakCelebration(days: days, gotFreeze: days == 7 || days == 30, onDismiss: { store.streakCelebration = nil })
                    .environmentObject(store)
                    .transition(.opacity)
                    .zIndex(11)
            } else if let pr = store.pendingPRs.first {
                PRCelebration(pr: pr, onDismiss: {
                    if !store.pendingPRs.isEmpty { store.pendingPRs.removeFirst() }
                })
                .environmentObject(store)
                .transition(.opacity)
                .zIndex(10)
            } else if let ach = store.celebrations.first {
                AchievementCelebration(achievement: ach, onDismiss: {
                    if !store.celebrations.isEmpty { store.celebrations.removeFirst() }
                })
                .environmentObject(store)
                .transition(.opacity)
                .zIndex(9)
            } else if let q = store.questCompleted.first {
                QuestCompleteCelebration(quest: q,
                    onClaim: { store.claimQuest(q); store.questCompleted.removeAll { $0.id == q.id } },
                    onDismiss: { if !store.questCompleted.isEmpty { store.questCompleted.removeFirst() } })
                .environmentObject(store)
                .transition(.opacity)
                .zIndex(8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.celebrations.count)
        .animation(.easeInOut(duration: 0.2), value: store.pendingPRs.count)
        .animation(.easeInOut(duration: 0.2), value: store.streakCelebration)
        .animation(.easeInOut(duration: 0.2), value: store.leaguePromoted)
        .animation(.easeInOut(duration: 0.2), value: store.questCompleted.count)
        // Aviso breve (toast) para avisos como "sesión no válida para la liga".
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
        .sheet(item: $profilePerson) { item in
            if let person = store.person(item.id) {
                FriendProfileView(person: person).environmentObject(store)
            }
        }
        .sheet(isPresented: $showProfile) {
            MeProfileView().environmentObject(store)
        }
        .fullScreenCover(isPresented: Binding(
            // Solo con sesión iniciada: al cerrar sesión (auth=nil) NO debe salir el onboarding.
            get: { store.auth != nil && ((store.account == nil && !store.checkingProfile) || editingAccount) },
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
        // Mientras comprobamos si ya tienes perfil en el servidor (para no repetir el onboarding).
        .overlay {
            if store.checkingProfile {
                ZStack {
                    Brand.bg.ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().scaleEffect(1.3)
                        Text("Cargando tu perfil…").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.soft)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func screen<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(tab == index ? 1 : 0)
            .allowsHitTesting(tab == index)
    }

    /// La primera vez que entras en una sección, Forgey te da un tour (una sola vez por sección).
    /// Espera a que la pantalla asiente y no interrumpe si ya hay un tour o una hoja abierta.
    private func maybeShowTour(_ t: Int) {
        guard store.account != nil, activeTour == nil else { return }
        let key = "tour-\(t)"
        guard !store.tourSeen(key) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard tab == t, activeTour == nil, !store.tourSeen(key),
                  chatPerson == nil, profilePerson == nil, !showMessages, !showNotifications, !showProfile else { return }
            activeTour = t
        }
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
