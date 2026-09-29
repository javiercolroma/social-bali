import SwiftUI

/// Discover · «Today's People» (PRODUCT.md, Fase 2). Los 10-15 perfiles del día que elige
/// el SERVIDOR (`todays_people()`), en un feed de tarjetas grandes con final explícito:
/// la escasez la pone el límite diario, no tener que pasar uno a uno (el «Siguiente»
/// confundía: parecía un match y no hacía nada).
struct DiscoverTodayView: View {
    @EnvironmentObject var store: AppStore

    @State private var people: [ProfileRow] = []
    @State private var seen = 0          // cuántos del mazo han pasado por pantalla
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
            } else {
                feed
            }
        }
        .background(Brand.bg)
        .task { await load() }
        // Cambio de día (medianoche de Bali) o carga fallida con la app en segundo plano.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if day != Self.baliDayString() || failed || people.isEmpty { Task { await load() } }
        }
        // Recién terminado el onboarding: el perfil acaba de subirse y el primer mazo pudo
        // llegar vacío (el servidor aún no te conocía). Se vuelve a pedir.
        .onChange(of: store.account?.handle) { _ in
            Task { try? await Task.sleep(nanoseconds: 2_500_000_000); await load() }
        }
        .sheet(item: $openProfile) { FriendProfileView(person: $0).environmentObject(store) }
    }

    // MARK: Feed

    private var feed: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                header
                ForEach(Array(people.enumerated()), id: \.element.id) { i, row in
                    DiscoverPersonCard(row: row) { FX.tap(); openProfile = AppStore.asPeople([row])[0] }
                        .onAppear { markSeen(i + 1) }
                }
                endOfDay
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .refreshable { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TODAY'S PEOPLE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Text(String(format: L10n.t("%lld people in Bali you might click with"), people.count))
                .font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Final explícito: no hay más hasta mañana.
    private var endOfDay: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundColor(Color(hex: "6ea300"))
            Text("That's everyone for today").font(.system(size: 19, weight: .heavy)).foregroundColor(Brand.ink)
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                Text(String(format: L10n.t("New people in %@"), Self.untilTomorrow(from: ctx.date)))
                    .font(.subheadline).foregroundColor(Brand.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    /// El servidor guarda hasta dónde has llegado (solo avanza), para métricas y Fase 3.
    private func markSeen(_ n: Int) {
        guard n > seen else { return }
        seen = n
        Task { await Backend.shared.setDiscoverPosition(n) }
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

    /// Reintenta en silencio antes de rendirse: el primer intento tras un arranque en frío
    /// puede caer mientras se restaura la sesión o vuelve la red.
    private func load() async {
        guard BackendConfig.isConfigured else { loading = false; return }
        loading = true
        defer { loading = false }
        for attempt in 0..<3 {
            do {
                let deck = try await Backend.shared.todaysPeople()
                people = deck.profiles
                seen = deck.position
                day = deck.day
                failed = false
                return
            } catch {
                print("[Discover] carga falló (intento \(attempt + 1)):", error)
                if attempt < 2 { try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_200_000_000) }
            }
        }
        failed = true
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

/// Tarjeta de una persona en el feed: que se VEA quién hay detrás. Foto grande (la de
/// perfil); sin foto, un fondo con su deporte principal en vez de un hueco gris.
struct DiscoverPersonCard: View {
    let row: ProfileRow
    var onOpen: () -> Void

    var body: some View {
        let club = row.club
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) {
                ZStack(alignment: .bottomLeading) {
                    photo(club)
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(row.name ?? row.handle ?? "").font(.system(size: 26, weight: .heavy))
                            if row.is_private == true { Image(systemName: "lock.fill").font(.system(size: 14)) }
                        }
                        HStack(spacing: 10) {
                            if let a = club.area { Label(a.label, systemImage: "mappin.and.ellipse") }
                            if let home = club.homeLine { Text(home) }
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .padding(16)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(4 / 5, contentMode: .fit)
                .clipped()
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                if let stay = club.stay {
                    HStack(spacing: 8) {
                        Label(stay.headline, systemImage: stay.kind == .livingHere ? "house.fill" : "airplane.departure")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
                        if let u = stay.urgency {
                            Text(u).font(.system(size: 11, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                                .padding(.horizontal, 8).frame(height: 22).background(Brand.redSoft).clipShape(Capsule())
                        }
                    }
                }
                if let bio = club.trimmedBio {
                    Text(bio).font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !club.sportList.isEmpty {
                    WrapLayout(spacing: 6) {
                        ForEach(club.sportList) { s in
                            Text("\(s.emoji) \(s.label)").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                                .padding(.horizontal, 10).frame(height: 28).background(Brand.chip).clipShape(Capsule())
                        }
                    }
                }
                if !club.intentList.isEmpty {
                    WrapLayout(spacing: 6) {
                        ForEach(club.intentList) { i in
                            Label(i.label, systemImage: i.icon)
                                .font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                .padding(.horizontal, 10).frame(height: 26)
                                .background(Brand.greenSoft).clipShape(Capsule())
                        }
                    }
                }
                Button(action: onOpen) {
                    Text("View profile").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            .padding(14)
        }
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Brand.line))
    }

    @ViewBuilder
    private func photo(_ club: ClubIdentity) -> some View {
        if let a = row.avatar_url, let u = URL(string: a) {
            Color.clear.overlay(
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { placeholder(club) }
            )
        } else {
            placeholder(club)
        }
    }

    /// Sin foto: degradado de marca + el emoji de su deporte principal, grande.
    private func placeholder(_ club: ClubIdentity) -> some View {
        ZStack {
            LinearGradient(colors: [Brand.greenSoft, Color(hex: "e7f0d6")], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(club.sportList.first?.emoji ?? "🙂").font(.system(size: 110)).offset(y: -30)
        }
    }
}
