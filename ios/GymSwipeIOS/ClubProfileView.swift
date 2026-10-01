import SwiftUI

/// El perfil **social** de una persona (lo que se abre desde Your Circle y desde las
/// solicitudes). Aspiracional, no una ficha de citas ni una hoja de estadísticas:
/// fotos → quién es y dónde está → situación en Bali → deportes → actividad → bio →
/// qué busca → Connect.
struct ClubProfileView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let personId: String
    /// Lo que ya se sabe (la celda del Circle) para pintar al instante mientras carga.
    var initial: ProfileRow? = nil

    @State private var row: ProfileRow?
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
                // El resto de la galería, tipo Pinterest.
                MediaGallery(items: Array((p.media ?? []).dropFirst()))
                if let stay = club.stay { baliStatus(stay) }
                if !club.sportList.isEmpty {
                    section("SPORTS & INTERESTS") {
                        WrapLayout(spacing: 6) {
                            ForEach(club.sportList) { s in chip("\(s.emoji) \(s.label)") }
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
                                    .font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                                    .padding(.horizontal, 11).frame(height: 30)
                                    .background(Brand.sand).clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    /// La pieza principal, en grande (foto, vídeo o Live Photo en movimiento).
    @ViewBuilder
    private func hero(_ p: ProfileRow) -> some View {
        Group {
            if let m = p.media?.first {
                MediaView(item: m)
            } else if let u = ([p.avatar_url].compactMap { $0 } + (p.photos ?? [])).first {
                RemoteFill(url: u)
            } else {
                ZStack {
                    LinearGradient(colors: [Brand.sand, Brand.sandDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(p.club.sportList.first?.emoji ?? "🙂").font(.system(size: 110))
                }
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
                    .font(.display(32)).foregroundColor(Brand.ink)
                if p.online == true {
                    HStack(spacing: 5) {
                        Circle().fill(Brand.online).frame(width: 9, height: 9)
                        Text("Active now").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.online)
                    }
                    .padding(.horizontal, 9).frame(height: 24)
                    .background(Brand.online.opacity(0.12)).clipShape(Capsule())
                }
            }
            if let d = p.distance_m {
                Label(CircleDistance.label(d) + " " + L10n.t("away"), systemImage: "location.fill")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(Brand.muted)
            }
            // Dónde vive y de dónde es: con presencia, no como una línea más.
            HStack(spacing: 10) {
                if let a = club.area { placeCard(L10n.t("LIVES IN"), a.label, symbol: "mappin.and.ellipse") }
                if let c = club.homeCountry, !c.isEmpty { placeCard(L10n.t("FROM"), countryName(c), flag: countryFlag(c)) }
            }
            .padding(.top, 6)
        }
    }

    private func placeCard(_ title: String, _ value: String, symbol: String? = nil, flag: String? = nil) -> some View {
        HStack(spacing: 10) {
            if let flag { Text(flag).font(.system(size: 30)) }
            else if let symbol {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.bronze)
                    .frame(width: 34, height: 34).background(Brand.sand).clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 10, weight: .bold)).tracking(1).foregroundColor(Brand.muted)
                Text(value).font(.display(17)).foregroundColor(Brand.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line))
    }

    /// «In Bali until Nov 12 · 2 weeks left»: lo que más cambia la utilidad de conectar.
    private func baliStatus(_ stay: Stay) -> some View {
        HStack(spacing: 12) {
            Image(systemName: stay.kind == .livingHere ? "house.fill" : stay.kind == .longTerm ? "calendar" : "airplane.departure")
                .font(.system(size: 18, weight: .semibold)).foregroundColor(Brand.bronze)
                .frame(width: 40, height: 40).background(Brand.sand.opacity(0.5)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("BALI STATUS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                Text(stay.headline).font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
            }
            Spacer()
            if let u = stay.urgency {
                Text(u).font(.system(size: 12, weight: .heavy)).foregroundColor(Brand.redText)
                    .padding(.horizontal, 9).frame(height: 24).background(Brand.redSoft).clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line))
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

    // MARK: Mensaje (fijo abajo) — chat directo, sin solicitud previa

    private func connectBar(_ p: ProfileRow) -> some View {
        Button {
            FX.tap()
            store.remember(AppStore.asPeople([p])[0])
            store.openChatWith = personId
        } label: {
            Label(String(format: L10n.t("Message %@"), p.name ?? ""), systemImage: "paperplane.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)
        .background(Brand.bg.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Datos y moderación

    private func load() async {
        guard BackendConfig.isConfigured else { return }
        do {
            if let fresh = try await Backend.shared.clubProfile(personId) {
                row = fresh
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
            try? await Backend.shared.blockUser(personId)
            store.loadConversations()
        }
        dismiss()
    }
}
