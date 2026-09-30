import SwiftUI

/// El perfil **social** de una persona (lo que se abre desde Your Circle y desde las
/// solicitudes). Aspiracional, no una ficha de citas ni una hoja de estadísticas:
/// fotos → quién es y dónde está → situación en Bali → deportes → actividad → bio →
/// qué busca → Connect. Los entrenos completos siguen en `FriendProfileView`.
struct ClubProfileView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let personId: String
    /// Lo que ya se sabe (la celda del Circle) para pintar al instante mientras carga.
    var initial: ProfileRow? = nil

    @State private var row: ProfileRow?
    @State private var showWorkouts = false
    @State private var confirmBlock = false

    private var current: ProfileRow? { row ?? initial }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    if let p = current {
                        content(p).padding(.bottom, 96)
                    } else {
                        ProgressView().tint(Brand.ink).padding(.top, 120)
                    }
                }
                if let p = current { connectBar(p) }
            }
            .background(Brand.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(Brand.ink)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) { report() } label: { Label("Report", systemImage: "flag") }
                        Button(role: .destructive) { confirmBlock = true } label: { Label("Block", systemImage: "hand.raised") }
                    } label: { Image(systemName: "ellipsis").foregroundColor(Brand.ink) }
                }
            }
            .confirmationDialog("Block this person?", isPresented: $confirmBlock, titleVisibility: .visible) {
                Button("Block", role: .destructive) { block() }
            } message: {
                Text("They won't see you and you won't see them. They aren't notified.")
            }
            .sheet(isPresented: $showWorkouts) {
                if let p = current { FriendProfileView(person: AppStore.asPeople([p])[0]).environmentObject(store) }
            }
        }
        .task { await load() }
        .onChange(of: store.openChatWith) { v in if v != nil { dismiss() } }
    }

    // MARK: Contenido

    @ViewBuilder
    private func content(_ p: ProfileRow) -> some View {
        let club = p.club.visible(toViewerOpenToDating: store.iAmOpenToDating)
        VStack(alignment: .leading, spacing: 22) {
            hero(p)
            VStack(alignment: .leading, spacing: 22) {
                identity(p, club)
                if let stay = club.stay { baliStatus(stay) }
                if !club.sportList.isEmpty {
                    section("SPORTS & INTERESTS") {
                        WrapLayout(spacing: 6) {
                            ForEach(club.sportList) { s in chip("\(s.emoji) \(s.label)") }
                        }
                    }
                }
                if let lines = activityLines(p.activity), !lines.isEmpty {
                    section("ACTIVITY") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(lines, id: \.text) { l in
                                Label(l.text, systemImage: l.icon)
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                            }
                        }
                    }
                }
                if let bio = club.trimmedBio {
                    section("BIO") {
                        Text(bio).font(.system(size: 17, weight: .semibold)).foregroundColor(Brand.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !club.intentList.isEmpty {
                    section("LOOKING FOR") {
                        WrapLayout(spacing: 6) {
                            ForEach(club.intentList) { i in
                                Label(i.label, systemImage: i.icon)
                                    .font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                    .padding(.horizontal, 11).frame(height: 30)
                                    .background(Brand.greenSoft).clipShape(Capsule())
                            }
                        }
                    }
                }
                if p.is_private != true {
                    Button { FX.tap(); showWorkouts = true } label: {
                        Label("See workouts", systemImage: "dumbbell.fill")
                            .font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.muted)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private func hero(_ p: ProfileRow) -> some View {
        var urls: [String] = []
        for u in [p.avatar_url].compactMap({ $0 }) + (p.photos ?? []) + (p.moments ?? []) where !urls.contains(u) {
            urls.append(u)
        }
        return PhotoPager(urls: urls) {
            ZStack {
                LinearGradient(colors: [Brand.greenSoft, Color(hex: "e7f0d6")], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(p.club.sportList.first?.emoji ?? "🙂").font(.system(size: 110))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4 / 5, contentMode: .fit)
        .clipped()
    }

    /// Nombre + edad, de dónde es, dónde está en Bali y a qué distancia.
    private func identity(_ p: ProfileRow, _ club: ClubIdentity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(p.age.map { "\(p.name ?? p.handle ?? ""), \($0)" } ?? (p.name ?? p.handle ?? ""))
                    .font(.system(size: 30, weight: .heavy)).foregroundColor(Brand.ink)
                if p.online == true {
                    HStack(spacing: 5) {
                        Circle().fill(Brand.green).frame(width: 9, height: 9)
                        Text("Online").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                    }
                }
            }
            let place = [club.area?.label, p.distance_m.map(CircleDistance.label)].compactMap { $0 }
            if !place.isEmpty {
                Label(place.joined(separator: " · "), systemImage: "mappin.and.ellipse")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.muted)
            }
            if let home = club.homeLine {
                Label(String(format: L10n.t("From %@"), home), systemImage: "globe.europe.africa.fill")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.muted)
            }
        }
    }

    /// «In Bali until Nov 12 · 2 weeks left»: lo que más cambia la utilidad de conectar.
    private func baliStatus(_ stay: Stay) -> some View {
        HStack(spacing: 12) {
            Image(systemName: stay.kind == .livingHere ? "house.fill" : stay.kind == .longTerm ? "calendar" : "airplane.departure")
                .font(.system(size: 18, weight: .semibold)).foregroundColor(Color(hex: "5e910e"))
                .frame(width: 40, height: 40).background(Brand.greenSoft.opacity(0.5)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("BALI STATUS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                Text(stay.headline).font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
            }
            Spacer()
            if let u = stay.urgency {
                Text(u).font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                    .padding(.horizontal, 9).frame(height: 24).background(Brand.redSoft).clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line))
    }

    private struct ActivityLine { let icon: String; let text: String }

    private func activityLines(_ a: ActivitySignals?) -> [ActivityLine]? {
        guard let a else { return nil }
        var out: [ActivityLine] = []
        if let n = a.per_week, n >= 1 {
            out.append(ActivityLine(icon: "figure.strengthtraining.traditional",
                                    text: String(format: L10n.t("Trains %lld× / week"), n)))
        }
        if a.active_this_week == true { out.append(ActivityLine(icon: "bolt.fill", text: L10n.t("Active this week"))) }
        if let s = a.week_streak, s >= 2 {
            out.append(ActivityLine(icon: "flame.fill", text: String(format: L10n.t("%lld week streak"), s)))
        }
        return out
    }

    private func section<C: View>(_ title: LocalizedStringKey, @ViewBuilder _ body: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            body()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
            .padding(.horizontal, 12).frame(height: 32).background(Brand.chip).clipShape(Capsule())
    }

    // MARK: Connect (fijo abajo)

    private func connectBar(_ p: ProfileRow) -> some View {
        ConnectControl(personId: personId,
                       theyAreOpenToDating: p.club.intentList.contains(.dating),
                       name: p.name ?? p.handle, photoURL: p.avatar_url)
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)
            .background(Brand.bg.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Datos y moderación

    private func load() async {
        guard BackendConfig.isConfigured else { return }
        store.loadConnections()
        do {
            if let fresh = try await Backend.shared.clubProfile(personId) {
                // `moments` solo llega en el Circle: se conservan si ya los había.
                var r = fresh
                if r.moments == nil { r.moments = initial?.moments }
                row = r
            } else if initial == nil {
                dismiss()   // no existe o hay un bloqueo
            }
        } catch {
            print("[ClubProfile] carga falló:", error)
        }
    }

    private func report() {
        FX.tap()
        Task { try? await Backend.shared.report(targetType: "user", targetId: personId, reportedUserId: personId, reason: "reported from club profile") }
        store.flashMessage = L10n.t("Thanks — we'll review it.")
    }

    private func block() {
        FX.warning()
        Task {
            if let uid = UUID(uuidString: personId) { try? await Backend.shared.unfollow(uid) }
            try? await Backend.shared.blockUser(personId)
            store.loadFollowing(); store.loadConnections()
        }
        dismiss()
    }
}
