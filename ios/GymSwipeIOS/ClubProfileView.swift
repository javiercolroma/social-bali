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
        VStack(alignment: .leading, spacing: 24) {
            hero(p)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom))
                .overlay(alignment: .bottomLeading) { heroTitle(p, club) }
            VStack(alignment: .leading, spacing: 24) {
                facts(p, club)
                if let bio = club.trimmedBio {
                    // La bio como cita, con la voz de la persona.
                    Text("“\(bio)”").font(.display(22, weight: .regular)).foregroundColor(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Identidad viva: lo que ha hecho de verdad (Highlights + Recent).
                MomentsSection(userId: personId)
                // El resto de la galería, tipo Pinterest.
                MediaGallery(items: Array((p.media ?? []).dropFirst()))
                if !club.sportList.isEmpty {
                    section("INTO") {
                        WrapLayout(spacing: 6) {
                            ForEach(club.sportList) { s in chip("\(s.emoji) \(s.label)") }
                        }
                    }
                }
                if !club.intentList.isEmpty {
                    section("LOOKING FOR") {
                        Text(club.intentList.map(\.label).joined(separator: " · "))
                            .font(.display(19)).foregroundColor(Brand.ink)
                    }
                }
            }
            .padding(.horizontal, 20)
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

    /// Nombre, edad y bandera sobre la foto (y «activo» si lo está).
    private func heroTitle(_ p: ProfileRow, _ club: ClubIdentity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                if p.online == true {
                    Circle().fill(Brand.online).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .accessibilityLabel(Text("Active now"))
                }
                Text(p.name ?? "").font(.display(38))
                if let a = p.age { Text("\(a)").font(.display(30, weight: .regular)).opacity(0.9) }
                if let c = club.homeCountry, !c.isEmpty { Text(countryFlag(c)).font(.system(size: 30)) }
            }
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.3), radius: 4)
        .padding(20)
    }

    /// País, zona, distancia y estancia en una línea que fluye — sin cajas.
    private func facts(_ p: ProfileRow, _ club: ClubIdentity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            WrapLayout(spacing: 14) {
                if let c = club.homeCountry, !c.isEmpty {
                    fact(Text(countryFlag(c)), "From", countryName(c))
                }
                if let a = club.area {
                    fact(Image(systemName: "mappin").foregroundColor(Brand.bronze), "Lives in", a.label)
                }
                if let d = p.distance_m {
                    fact(Image(systemName: "location.north.fill").foregroundColor(Brand.bronze), nil,
                         CircleDistance.label(d) + " " + L10n.t("away"))
                }
            }
            if let stay = club.stay {
                HStack(spacing: 6) {
                    Image(systemName: stay.kind == .livingHere ? "house" : stay.kind == .longTerm ? "calendar" : "airplane")
                        .foregroundColor(Brand.bronze)
                    Text(stay.headline).foregroundColor(Brand.ink)
                    if let u = stay.urgency {
                        Text("— " + u).foregroundColor(Brand.redText)
                    }
                }
                .font(.system(size: 15, weight: .medium))
            }
        }
    }

    private func fact<I: View>(_ icon: I, _ lead: LocalizedStringKey?, _ value: String) -> some View {
        HStack(spacing: 6) {
            icon.font(.system(size: 15))
            if let lead { Text(lead).foregroundColor(Brand.muted) }
            Text(value).fontWeight(.semibold).foregroundColor(Brand.ink)
        }
        .font(.system(size: 15))
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
