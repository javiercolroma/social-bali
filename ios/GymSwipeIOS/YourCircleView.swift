import SwiftUI
import CoreLocation

/// **Your Circle**. Las 12-15 personas del día que elige el SERVIDOR (`your_circle()`),
/// en una rejilla tipo Pinterest con fotos y vídeos en movimiento. Quién está en tu
/// Circle se fija una vez al día (hora de Bali); la distancia y el «online» se
/// recalculan en cada carga. Final explícito: no hay scroll infinito.
///
/// Dos puertas antes de entrar (decisión del 2026-09-30):
///   · sin permiso de ubicación no se entra (es lo que demuestra que estás en Bali);
///   · si la ubicación aún no te sitúa en Bali, se enseña la llegada.
struct YourCircleView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var presence = PresenceService.shared

    @State private var people: [ProfileRow] = []
    @State private var area: String?
    @State private var locked = false
    @State private var seen = 0
    @State private var loading = true
    @State private var failed = false
    @State private var openProfile: ProfileRow?
    @State private var showRequests = false

    var body: some View {
        Group {
            if !presence.canUseLocation {
                LocationRequiredView()
            } else if locked {
                ArrivalView(onRefresh: { await load() })
            } else if loading && people.isEmpty {
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await load() }
        }
        .onChange(of: store.account?.handle) { _ in
            Task { try? await Task.sleep(nanoseconds: 2_500_000_000); await load() }
        }
        // Acaba de dar permiso: se espera a que la posición llegue al servidor.
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
            VStack(alignment: .leading, spacing: 18) {
                header
                if !store.incomingRequests.isEmpty { requestsBanner }
                Masonry(spacing: 10, aspects: people.map(Self.aspect)) {
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

    /// Alturas distintas aunque falten medidas, para que la rejilla respire.
    static func aspect(_ r: ProfileRow) -> CGFloat {
        if let a = r.media?.first?.aspect { return a }
        return r.id.uuidString.last.map { "02468ace".contains($0.lowercased()) } == true ? 3 / 4 : 4 / 5
    }

    private var newCount: Int { people.filter { $0.first_time == true || $0.badge == "new" || $0.badge == "just_arrived" }.count }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YOUR CIRCLE").font(.system(size: 11, weight: .bold)).tracking(1.6).foregroundColor(Brand.muted)
            Text(Neighborhood(rawValue: area ?? "")?.label ?? "Bali").font(.display(34)).foregroundColor(Brand.ink)
            Text(newCount > 0
                 ? String(format: L10n.t("%1$lld people around you today · %2$lld new"), people.count, newCount)
                 : String(format: L10n.t("%lld people around you today"), people.count))
                .font(.system(size: 14, weight: .medium)).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var requestsBanner: some View {
        Button { FX.tap(); showRequests = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "hand.wave.fill").font(.system(size: 16))
                Text(String(format: L10n.t("%lld people want to connect"), store.incomingRequests.count))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(Brand.onAccent)
            .padding(.horizontal, 16).frame(height: 52)
            .background(Brand.accent).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }.buttonStyle(.plain)
    }

    private var endOfDay: some View {
        VStack(spacing: 8) {
            Text("You've met everyone in your circle today.")
                .font(.display(19)).foregroundColor(Brand.ink).multilineTextAlignment(.center)
            Text("New people will appear as your community changes around you.")
                .font(.subheadline).foregroundColor(Brand.muted).multilineTextAlignment(.center)
            TimelineView(.periodic(from: .now, by: 60)) { ctx in
                Text(String(format: L10n.t("New circle in %@"), Self.untilTomorrow(from: ctx.date)))
                    .font(.system(size: 11, weight: .bold)).tracking(1).foregroundColor(Brand.soft)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30).padding(.horizontal, 12)
    }

    private func markSeen(_ n: Int) {
        guard n > seen else { return }
        seen = n
        Task { await Backend.shared.setDiscoverPosition(n) }
    }

    private func message(icon: String, title: LocalizedStringKey, text: LocalizedStringKey,
                         action: (LocalizedStringKey, () -> Void)?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundColor(Brand.soft)
            Text(title).font(.display(22)).foregroundColor(Brand.ink).multilineTextAlignment(.center)
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
        guard BackendConfig.isConfigured, presence.canUseLocation else { loading = false; return }
        loading = true
        defer { loading = false }
        for attempt in 0..<3 {
            do {
                let deck = try await Backend.shared.yourCircle()
                store.loadConnections()
                locked = deck.locked == true
                people = deck.profiles
                area = deck.area
                seen = deck.position
                failed = false
                return
            } catch {
                print("[Circle] carga falló (intento \(attempt + 1)):", error)
                if attempt < 2 { try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_200_000_000) }
            }
        }
        failed = true
    }

    private static let bali = TimeZone(identifier: "Asia/Makassar") ?? .current

    static func untilTomorrow(from now: Date) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = bali
        let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
        let mins = max(0, Int(next.timeIntervalSince(now) / 60))
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(max(1, mins))m"
    }
}

// MARK: - Celda

/// Una persona en la rejilla: su foto o vídeo principal, nombre, edad y UN indicador.
struct CircleCell: View {
    let row: ProfileRow
    let myArea: String?
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            Color.clear
                .overlay(cover)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(nameLine).font(.system(size: 16, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                            if row.online == true {
                                Circle().fill(Brand.online).frame(width: 8, height: 8)
                                    .accessibilityLabel(Text("Online"))
                            }
                        }
                        if let sub = subline {
                            Text(sub).font(.system(size: 12, weight: .medium)).opacity(0.85).lineLimit(1)
                        }
                    }
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3)
                    .padding(11)
                }
                .overlay(alignment: .topLeading) {
                    if let b = badgeText {
                        Text(b).font(.system(size: 9, weight: .bold)).tracking(0.8)
                            .foregroundColor(Brand.ink)
                            .padding(.horizontal, 8).frame(height: 20)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(9)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var nameLine: String {
        let name = row.name ?? ""
        return row.age.map { "\(name), \($0)" } ?? name
    }

    private var subline: String? {
        if let m = row.distance_m { return CircleDistance.label(m) }
        return row.club.area?.label
    }

    private var badgeText: String? {
        switch row.badge {
        case "just_arrived": return L10n.t("JUST ARRIVED")
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

    @ViewBuilder
    private var cover: some View {
        if let m = row.media?.first {
            MediaView(item: m)
        } else if let url = ([row.avatar_url].compactMap { $0 } + (row.photos ?? [])).first {
            RemoteFill(url: url)
        } else {
            ZStack {
                LinearGradient(colors: [Brand.sand, Brand.sandDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(row.club.sportList.first?.emoji ?? "🙂").font(.system(size: 54)).offset(y: -14)
            }
        }
    }
}

// MARK: - Puertas: ubicación y llegada

/// Sin ubicación no hay club: es lo que confirma que estás en Bali y quién hay cerca.
struct LocationRequiredView: View {
    @ObservedObject private var presence = PresenceService.shared

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.circle").font(.system(size: 54, weight: .ultraLight)).foregroundColor(Brand.bronze)
            Text("Share your location to enter").font(.display(26)).foregroundColor(Brand.ink).multilineTextAlignment(.center)
            Text("Bali Circle is for people who are in Bali right now. Your location confirms it and shows who's around you. Others only ever see how far away you are — never where.")
                .font(.subheadline).foregroundColor(Brand.muted).multilineTextAlignment(.center)
            Button { FX.tap(); presence.requestPermission() } label: {
                Text(presence.locationDenied ? "Open Settings" : "Share my location")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 6)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.bg)
    }
}

/// Aún no estás en Bali: tu perfil está listo y el Circle se abre al llegar.
struct ArrivalView: View {
    @EnvironmentObject var store: AppStore
    var onRefresh: () async -> Void

    private var daysToGo: Int? {
        guard let d = store.profile.arrivalDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Spacer(minLength: 60)
                Text("🌴").font(.system(size: 54))
                Text("Your circle opens when you land in Bali").font(.display(28)).foregroundColor(Brand.ink)
                    .multilineTextAlignment(.center)
                if let n = daysToGo, n > 0 {
                    Text(n == 1 ? L10n.t("ARRIVING TOMORROW") : String(format: L10n.t("ARRIVING IN %lld DAYS"), n))
                        .font(.system(size: 12, weight: .bold)).tracking(1.2).foregroundColor(Brand.bronze)
                }
                Text("Your profile is ready. As soon as your location shows you're in Bali, you'll see who's around and they'll see you — as JUST ARRIVED.")
                    .font(.subheadline).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                Button { FX.tap(); Task { await onRefresh() } } label: { Text("I'm in Bali — check again") }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 6)
            }
            .padding(.horizontal, 32)
        }
        .refreshable { await onRefresh() }
        .background(Brand.bg)
    }
}

/// Para abrir un perfil del Circle con `.sheet(item:)`.
extension ProfileRow: Identifiable {}
