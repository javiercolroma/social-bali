import SwiftUI

struct IdString: Identifiable { let id: String }

struct RootView: View {
    @EnvironmentObject var store: AppStore
    /// Discover es la pestaña 5 (se añadió la última) pero se MUESTRA la primera y es la
    /// de arranque. Los índices 0-4 no se renumeran: los tutoriales (`tour-N`,
    /// `CoachTour.content`) y varias navegaciones (`tab = 2`…) dependen de ellos.
    static let discoverTab = 5
    @State private var tab = RootView.discoverTab
    @State private var showMessages = false
    @State private var messagesTab = 0
    @State private var showNotifications = false
    @State private var editingAccount = false
    @State private var chatPerson: IdString?
    @State private var profilePerson: IdString?
    @State private var showProfile = false
    @State private var activeTour: Int?   // sección cuyo tutorial se está mostrando
    @State private var tourTarget: String?   // componente resaltado en el paso actual del tour
    @State private var showForgey = false    // chat con Forgey (IA on-device)


    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                screen(0) { SocialFeedView(onOpenProfile: { profilePerson = IdString(id: $0) },
                                           onOpenMyProfile: { showProfile = true }) }
                screen(1) { PlanView(onLoaded: { tab = 2 }) }
                screen(2) { TrainView(onGoToPlan: { tab = 1 }) }
                // Comunidad (Ranking + Partner) fuera de la barra desde 2026-09-29: el ranking es
                // lenguaje de app de fitness, no de club. Partner vuelve como «Actividades»
                // (PRODUCT.md, Fase 4), por eso el código se conserva.
                screen(4) { ActivityView() }
                screen(RootView.discoverTab) {
                    YourCircleView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Forgey se ASOMA por el lateral, esperando a ayudar (toca → chat IA;
            // ARRASTRA para colocarlo a tu gusto). Solo si el dispositivo soporta la IA.
            .overlay {
                if ForgeyEngine.isAvailable {
                    ForgeyPeek { FX.tap(); showForgey = true }.tourAnchor("forgey.peek")
                }
            }
            .onChange(of: tab) { t in FX.selection(); maybeShowTour(t) }

            // .id(tab): fuerza el re-render de la barra al cambiar de pestaña — sin él,
            // SwiftUI a veces se salta el refresco y el resaltado se queda "pegado".
            CustomTabBar(tab: tab, onSelect: { tab = $0 }).id(tab)
        }
        .background(Brand.bg.ignoresSafeArea())
        .sheet(isPresented: $showForgey) { ForgeyChatView().environmentObject(store) }
        .onAppear { maybeShowTour(tab) }
        // Invitación por deep link: abre el perfil del que te invitó, listo para seguirle.
        .onReceive(store.$deepLinkPersonId.compactMap { $0 }) { pid in
            profilePerson = IdString(id: pid)
            store.deepLinkPersonId = nil
        }
        // «Message» / aceptar una conexión: cierra lo que haya encima y abre el chat.
        .onReceive(store.$openChatWith.compactMap { $0 }) { pid in
            profilePerson = nil; showProfile = false; showMessages = false; showNotifications = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                chatPerson = IdString(id: pid)
                // Se limpia DESPUÉS: las hojas que no son de RootView (perfil y solicitudes
                // abiertos desde Descubrir) se cierran al VER el valor; si se limpiara en el
                // mismo instante, SwiftUI podría fundir los dos cambios y no verían ninguno.
                store.openChatWith = nil
            }
        }
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
        guard store.account != nil, activeTour == nil, t != RootView.discoverTab else { return }
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
            // Solo la marca: el título de la sección (Social, Plan…) se quitó porque ya lo
            // dice la barra de abajo, que además va resaltada. Repetirlo en 30pt comía una
            // franja de pantalla en cada vista para no aportar nada.
            Text("FORGE LOOP")
                .font(.system(size: 17, weight: .heavy)).kerning(1.6)
                .foregroundColor(Color(hex: "4b6211"))
                .lineLimit(1)
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
    /// (índice de pestaña, título, icono) en el ORDEN en que se muestran.
    private let items: [(idx: Int, title: String, icon: String)] = [
        (RootView.discoverTab, "Circle", "circle.grid.2x2.fill"),
        (0, "Social", "newspaper.fill"),
        (1, "Plan", "list.bullet.clipboard"),
        (2, "Entreno", "dumbbell.fill"),
        (4, "Actividad", "chart.bar.fill"),
    ]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(items, id: \.idx) { item in
                // Entreno mantiene su botón destacado; el resto son elementos suaves.
                if item.idx == 2 { centerItem(item.idx, (item.title, item.icon)) }
                else { tabItem(item.idx, (item.title, item.icon)) }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, max(8, safeBottom))
        .background(Brand.bg)
    }

    /// Botón central de Entreno: círculo elevado (como estaba), con toque suave.
    private func centerItem(_ idx: Int, _ item: (title: String, icon: String)) -> some View {
        let active = tab == idx
        return VStack(spacing: 4) {
            Image(systemName: item.icon).font(.system(size: 20, weight: .heavy))
                .foregroundStyle(active ? Color(hex: "10150a") : Brand.soft)
                .frame(width: 50, height: 50)
                .background(active ? Brand.green : Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(active ? Color.clear : Brand.line, lineWidth: 1))
                .shadow(color: active ? Brand.green.opacity(0.4) : .black.opacity(0.06), radius: active ? 8 : 4, y: 3)
            Text(LocalizedStringKey(item.title)).font(.system(size: 10, weight: .heavy)).foregroundStyle(active ? accent : Brand.soft)
        }
        .frame(maxWidth: .infinity)
        .offset(y: -8)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(idx) }
    }

    private var safeBottom: CGFloat {
        (UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?
            .windows.first?.safeAreaInsets.bottom) ?? 0
    }

    private let accent = Color(hex: "5e910e")

    /// Elemento del menú: toque suave con la píldora verde encendida SOLO en la pestaña
    /// activa (sin deslizarse entre pestañas: aparece directamente donde estás).
    private func tabItem(_ idx: Int, _ item: (title: String, icon: String)) -> some View {
        let active = tab == idx
        return VStack(spacing: 5) {
            ZStack {
                if active {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Brand.greenSoft)
                        .frame(width: 54, height: 34)
                }
                Image(systemName: item.icon)
                    .font(.system(size: 19, weight: active ? .heavy : .medium))
                    .foregroundStyle(active ? accent : Brand.soft)
                    .scaleEffect(active ? 1.06 : 1)
            }
            .frame(height: 34)
            Text(LocalizedStringKey(item.title))
                .font(.system(size: 10, weight: active ? .heavy : .semibold))
                .foregroundStyle(active ? accent : Brand.soft)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(idx) }
    }
}


/// Forgey asomándose por el borde derecho, como esperando a ayudar: medio cuerpo fuera,
/// inclinado y saludando. ARRASTRABLE verticalmente (recuerda su posición entre sesiones).
/// Cada pocos segundos se asoma un poco más. Toca → chat IA.
struct ForgeyPeek: View {
    var action: () -> Void
    /// Posición vertical como fracción de la pantalla (persistida).
    @AppStorage("forgeyPeekYFrac") private var yFrac = 0.40
    @State private var dragY: CGFloat = 0
    @State private var peeking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let baseY = CGFloat(yFrac) * geo.size.height
            Mascot(size: 52, wave: true)
                .rotationEffect(.degrees(-16))
                // El símbolo clásico de IA (✨) sobre la parte visible, siempre derecho.
                .overlay(alignment: .topLeading) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Color(hex: "4b6211"))
                        .padding(5)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(Brand.line))
                        .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                        .offset(x: -4, y: 0)
                }
                .shadow(color: .black.opacity(0.14), radius: 8, x: -2, y: 3)
                // En reposo: medio cuerpo fuera. Al "asomarse" o arrastrar: entra un poco más.
                .offset(x: (peeking || dragY != 0) ? 18 : 30)
                .position(x: geo.size.width - 20, y: min(max(baseY + dragY, 50), geo.size.height - 50))
                .onTapGesture { action() }
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { dragY = $0.translation.height }
                        .onEnded { v in
                            let final = min(max(baseY + v.translation.height, 50), geo.size.height - 50)
                            yFrac = Double(final / max(1, geo.size.height))
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { dragY = 0 }
                        }
                )
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: peeking)
        }
        .onAppear {
            guard !reduceMotion else { return }
            scheduleWiggle()
        }
    }

    /// Se asoma 1,2 s cada ~5-7 s (suave, sin ser pesado).
    private func scheduleWiggle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 4.5...7.5)) {
            peeking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                peeking = false
                scheduleWiggle()
            }
        }
    }
}