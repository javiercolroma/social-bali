import SwiftUI
import CoreLocation

/// **Your Circle** (antes «Today's People»). Las 12-15 personas del día que elige el
/// SERVIDOR (`your_circle()`, migración 0028), en una rejilla de 2 columnas con foto
/// grande. Quién está en tu Circle se fija una vez al día (hora de Bali); la distancia y
/// el «online» se recalculan en cada carga. Final explícito: no hay scroll infinito.
struct YourCircleView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var presence = PresenceService.shared

    @State private var people: [ProfileRow] = []
    @State private var area: String?
    @State private var seen = 0          // cuántos del Circle han pasado por pantalla
    @State private var day: String?
    @State private var loading = true
    @State private var failed = false
    @State private var openProfile: ProfileRow?
    @State private var showRequests = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        Group {
            if loading && people.isEmpty {
                ProgressView().tint(Brand.ink).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed && people.isEmpty {
                message(icon: "wifi.exclamationmark", title: "Couldn't load your circle",
                        text: "Check your connection and try again.", action: ("Try again", { Task { await load() } }))
            } else if people.isEmpty {
                message(icon: "person.2.wave.2", title: "No one new today",
                        text: "The club is still growing. New people show up here every day.", action: nil)
            } else {
                grid
            }
        }
        .background(Brand.bg)
        .task { await load() }
        // Al volver: la distancia y el online cambian aunque el Circle del día sea el mismo.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await load() }
        }
        // Recién terminado el onboarding: el primer Circle pudo llegar vacío.
        .onChange(of: store.account?.handle) { _ in
            Task { try? await Task.sleep(nanoseconds: 2_500_000_000); await load() }
        }
        // Acaba de dar permiso de ubicación: se espera a que la posición llegue al servidor.
        .onChange(of: presence.canUseLocation) { ok in
            if ok { Task { try? await Task.sleep(nanoseconds: 3_000_000_000); await load() } }
        }
        .sheet(item: $openProfile) { ClubProfileView(personId: $0.id.uuidString.lowercased(), initial: $0).environmentObject(store) }
        .sheet(isPresented: $showRequests) { ConnectionRequestsSheet().environmentObject(store) }
        .onChange(of: store.openChatWith) { v in if v != nil { openProfile = nil } }
    }

    // MARK: Rejilla

    private var grid: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !store.incomingRequests.isEmpty { requestsBanner }
                header
                if !presence.canUseLocation { locationBanner }
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { i, row in
                        CircleCell(row: row, myArea: area) { FX.tap(); openProfile = row }
                            .onAppear { markSeen(i + 1) }
                    }
                }
                endOfDay
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .refreshable { await load() }
    }

    private var newCount: Int { people.filter { $0.first_time == true || $0.badge == "new" }.count }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("YOUR CIRCLE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Text(Neighborhood(rawValue: area ?? "")?.label ?? "Bali")
                .font(.system(size: 28, weight: .heavy)).foregroundColor(Brand.ink)
            Text(newCount > 0
                 ? String(format: L10n.t("%1$lld people around you today · %2$lld new"), people.count, newCount)
                 : String(format: L10n.t("%lld people around you today"), people.count))
                .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sin ubicación el Circle funciona igual (por barrio), pero sin distancias.
    private var locationBanner: some View {
        Button { FX.tap(); presence.requestPermission() } label: {
            HStack(spacing: 12) {
                Image(systemName: "location.circle.fill").font(.system(size: 26)).foregroundColor(Color(hex: "5e910e"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("See who's close by").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("Turn on location to see distances. Others only ever see how far you are, never where.")
                        .font(.caption).foregroundColor(Brand.muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
            }
            .padding(14)
            .background(Brand.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line))
        }.buttonStyle(.plain)
    }

    private var requestsBanner: some View {
        Button { FX.tap(); showRequests = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "hand.wave.fill").font(.system(size: 18))
                Text(String(format: L10n.t("%lld people want to connect"), store.incomingRequests.count))
                    .font(.system(size: 15, weight: .heavy))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(Color(hex: "10150a"))
            .padding(.horizontal, 14).frame(height: 52)
            .background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain)
    }

    /// Final explícito: una selección, no un catálogo.
    private var endOfDay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 32)).foregroundColor(Color(hex: "6ea300"))
            Text("You've met everyone in your circle today.")
                .font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink).multilineTextAlignment(.center)
            Text("New people will appear as your community changes around you.")
                .font(.subheadline).foregroundColor(Brand.muted).multilineTextAlignment(.center)
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                Text(String(format: L10n.t("New circle in %@"), Self.untilTomorrow(from: ctx.date)))
                    .font(.caption).fontWeight(.heavy).foregroundColor(Brand.soft)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28).padding(.horizontal, 12)
    }

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

    /// Reintenta en silencio: tras un arranque en frío la sesión puede no estar lista.
    private func load() async {
        guard BackendConfig.isConfigured else { loading = false; return }
        loading = true
        defer { loading = false }
        for attempt in 0..<3 {
            do {
                let deck = try await Backend.shared.yourCircle()
                store.loadConnections()
                people = deck.profiles
                area = deck.area
                seen = deck.position
                day = deck.day
                failed = false
                return
            } catch {
                print("[Circle] carga falló (intento \(attempt + 1)):", error)
                if attempt < 2 { try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_200_000_000) }
            }
        }
        failed = true
    }

    // MARK: Día de Bali (el mismo reloj que el servidor)

    private static let bali = TimeZone(identifier: "Asia/Makassar") ?? .current

    /// «5h 12m» hasta la medianoche de Bali, cuando llega el Circle nuevo.
    static func untilTomorrow(from now: Date) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = bali
        let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        let mins = max(0, Int(next.timeIntervalSince(now) / 60))
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(max(1, mins))m"
    }
}

// MARK: - Celda

/// Una persona en la rejilla: foto, nombre, edad y UN indicador corto. Nada más.
struct CircleCell: View {
    let row: ProfileRow
    let myArea: String?
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .bottomLeading) {
                photo
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(nameLine).font(.system(size: 17, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8)
                        if row.online == true {
                            Circle().fill(Brand.green).frame(width: 9, height: 9)
                                .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1))
                                .accessibilityLabel(Text("Online"))
                        }
                    }
                    if let sub = subline {
                        Text(sub).font(.system(size: 12, weight: .semibold)).opacity(0.9).lineLimit(1)
                    }
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.35), radius: 3)
                .padding(10)
            }
            .overlay(alignment: .topLeading) {
                if let b = badgeText {
                    Text(b).font(.system(size: 10, weight: .heavy)).tracking(0.4)
                        .foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 8).frame(height: 22)
                        .background(Brand.green).clipShape(Capsule())
                        .padding(8)
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var nameLine: String {
        let name = row.name ?? row.handle ?? ""
        return row.age.map { "\(name), \($0)" } ?? name
    }

    /// Distancia si la hay; si no, su barrio.
    private var subline: String? {
        if let m = row.distance_m { return CircleDistance.label(m) }
        return row.club.area?.label
    }

    private var badgeText: String? {
        switch row.badge {
        case "new": return L10n.t("NEW")
        case "new_in_area":
            let a = row.club.area?.label ?? Neighborhood(rawValue: myArea ?? "")?.label ?? "Bali"
            return String(format: L10n.t("NEW IN %@"), a.uppercased())
        case "leaving":
            guard let d = row.days_left else { return nil }
            switch d {
            case 0: return L10n.t("LAST DAY HERE")
            case 1..<14: return String(format: L10n.t("HERE FOR %lld DAYS"), d)
            default: return L10n.t("HERE FOR 2 WEEKS")
            }
        case "nearby": return L10n.t("NEARBY")
        default: return nil
        }
    }

    private var photo: some View {
        let url = ([row.avatar_url].compactMap { $0 } + (row.photos ?? []) + (row.moments ?? [])).first
        return Group {
            if let url { RemoteFill(url: url) }
            else {
                ZStack {
                    LinearGradient(colors: [Brand.greenSoft, Color(hex: "e7f0d6")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(row.club.sportList.first?.emoji ?? "🙂").font(.system(size: 64)).offset(y: -16)
                }
            }
        }
    }
}

/// Para abrir un perfil del Circle con `.sheet(item:)`.
extension ProfileRow: Identifiable {}
