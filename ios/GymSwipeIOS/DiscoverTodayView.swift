import SwiftUI

/// Discover · «Today's People» (PRODUCT.md, Fase 2). 10-15 perfiles al día, elegidos
/// por el SERVIDOR (`todays_people()`), uno detrás de otro y con final explícito:
/// escasez, no swipe infinito. Conectar con motivo llega en la Fase 3; de momento se
/// mira el perfil (desde ahí se puede seguir) o se pasa al siguiente.
struct DiscoverTodayView: View {
    @EnvironmentObject var store: AppStore
    /// Al acabar: empujón a hacer algo en persona (planes de Partner → Actividades).
    var onOpenPlans: () -> Void

    @State private var people: [ProfileRow] = []
    @State private var position = 0
    @State private var day: String?
    @State private var loading = true
    @State private var failed = false
    @State private var openProfile: SocialPerson?

    var body: some View {
        Group {
            if loading && people.isEmpty {
                ProgressView().tint(Brand.ink).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed && people.isEmpty {
                message(icon: "wifi.exclamationmark", title: "Couldn't load today's people",
                        text: "Check your connection and try again.", action: ("Try again", { Task { await load() } }))
            } else if people.isEmpty {
                message(icon: "person.2.wave.2", title: "No one new today",
                        text: "The club is still growing. New people show up here every day.", action: nil)
            } else if position >= people.count {
                doneView
            } else {
                deckView
            }
        }
        .background(Brand.bg)
        .task { await load() }
        // Cambio de día (medianoche de Bali) con la app en segundo plano → mazo nuevo.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if day != Self.baliDayString() { Task { await load() } }
        }
        .sheet(item: $openProfile) { FriendProfileView(person: $0).environmentObject(store) }
    }

    // MARK: Mazo

    private var deckView: some View {
        let row = people[position]
        let person = AppStore.asPeople([row])[0]
        let club = row.club
        return ScrollView {
            VStack(spacing: 14) {
                progress
                VStack(spacing: 10) {
                    ScoredAvatar(emoji: club.sportList.first?.emoji ?? "🙂", avatarURL: row.avatar_url,
                                 score: row.gym_score ?? 0, size: 96)
                    VStack(spacing: 3) {
                        HStack(spacing: 6) {
                            Text(row.name ?? row.handle ?? "").font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                            if row.is_private == true { Image(systemName: "lock.fill").font(.system(size: 13)).foregroundColor(Brand.soft) }
                        }
                        if let h = row.handle { Text("@\(h)").font(.subheadline).foregroundColor(Brand.muted) }
                    }
                }
                .padding(.top, 4)
                ClubIdentityCard(club: club)
                HStack(spacing: 10) {
                    Button { FX.tap(); openProfile = person } label: {
                        Text("View profile").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                    Button { next() } label: {
                        HStack(spacing: 6) { Text("Next"); Image(systemName: "arrow.right") }
                    }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(16)
            .id(row.id)   // cada perfil entra como pantalla nueva (y el scroll vuelve arriba)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
        }
    }

    /// «3 of 15» + barra: se ve que hay un final.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODAY'S PEOPLE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                Spacer()
                Text(String(format: L10n.t("%lld of %lld"), position + 1, people.count))
                    .font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Brand.chip)
                    Capsule().fill(Brand.green)
                        .frame(width: g.size.width * CGFloat(position + 1) / CGFloat(max(1, people.count)))
                }
            }
            .frame(height: 5)
        }
    }

    private func next() {
        FX.selection()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { position += 1 }
        let p = position
        Task { await Backend.shared.setDiscoverPosition(p) }
        if p >= people.count { FX.success() }
    }

    // MARK: Final del día

    private var doneView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 46)).foregroundColor(Color(hex: "6ea300"))
            Text("That's everyone for today").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                .multilineTextAlignment(.center)
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                Text(String(format: L10n.t("New people in %@"), Self.untilTomorrow(from: ctx.date)))
                    .font(.subheadline).foregroundColor(Brand.muted)
            }
            Text("The best way to meet them is to do something together.")
                .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button { FX.tap(); onOpenPlans() } label: {
                Label("See plans nearby", systemImage: "figure.run")
            }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 24)
            Button { FX.tap(); withAnimation { position = 0 } } label: {
                Text("Look through today's people again").font(.footnote).fontWeight(.semibold).foregroundColor(Brand.soft)
            }.buttonStyle(.plain)
            Spacer()
        }
        .padding(16)
    }

    private func message(icon: String, title: LocalizedStringKey, text: LocalizedStringKey,
                         action: (LocalizedStringKey, () -> Void)?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 38)).foregroundColor(Brand.soft)
            Text(title).font(.system(size: 19, weight: .heavy)).foregroundColor(Brand.ink).multilineTextAlignment(.center)
            Text(text).font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
            if let action {
                Button { FX.tap(); action.1() } label: { Text(action.0) }
                    .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 40).padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Carga

    private func load() async {
        guard BackendConfig.isConfigured else { loading = false; return }
        loading = true
        defer { loading = false }
        do {
            let deck = try await Backend.shared.todaysPeople()
            people = deck.profiles
            position = min(deck.position, deck.profiles.count)
            day = deck.day
            failed = false
        } catch {
            print("[Discover] carga falló:", error)
            failed = true
        }
    }

    // MARK: Día de Bali (el mismo reloj que el servidor)

    private static let bali = TimeZone(identifier: "Asia/Makassar") ?? .current

    static func baliDayString(_ now: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = bali; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: now)
    }

    /// «5h 12m» hasta la medianoche de Bali, cuando llega el mazo nuevo.
    static func untilTomorrow(from now: Date) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = bali
        let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        let mins = max(0, Int(next.timeIntervalSince(now) / 60))
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(max(1, mins))m"
    }
}
