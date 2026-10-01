import SwiftUI
import PhotosUI
import Supabase

func normalizeHandle(_ value: String) -> String {
    let lower = value.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    let filtered = lower.unicodeScalars.filter { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_").contains($0) }
    return String(String.UnicodeScalarView(filtered)).prefix(20).description
}

func emptyState(icon: String, title: String, body: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon).font(.system(size: 26)).foregroundColor(Brand.soft)
        Text(title).font(.system(size: 16, weight: .heavy)).foregroundColor(Color(hex: "41463c"))
        Text(body).font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
    }.padding(.top, 60).padding(.horizontal, 30).frame(maxWidth: .infinity)
}

// MARK: - Avatar

/// Foto de perfil redonda; sin foto, el emoji de su primer deporte.
struct PersonAvatar: View {
    let person: SocialPerson?
    var size: CGFloat = 44
    var body: some View {
        Group {
            if let url = person?.avatarURL { RemoteFill(url: url) }
            else { Brand.sand.overlay(Text(person?.club?.sportList.first?.emoji ?? "🙂").font(.system(size: size * 0.45))) }
        }
        .frame(width: size, height: size).clipShape(Circle())
    }
}

// MARK: - Mi perfil (pestaña Profile)

/// Tu perfil tal y como lo ven los demás, con el botón de editar y los ajustes.
struct MeProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing = false
    @State private var settings = false

    private var nameLine: String {
        let name = store.account?.name ?? ""
        guard let b = store.profile.birthdate,
              let y = Calendar.current.dateComponents([.year], from: b, to: Date()).year else { return name }
        return "\(name), \(y)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    if let m = store.profile.media?.first {
                        MediaView(item: m)
                    } else if let d = store.account?.photoData, let img = UIImage(data: d) {
                        Color.clear.overlay(Image(uiImage: img).resizable().scaledToFill())
                    } else {
                        Button { editing = true } label: {
                            ZStack {
                                LinearGradient(colors: [Brand.sand, Brand.sandDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                                VStack(spacing: 8) {
                                    Image(systemName: "photo.stack").font(.system(size: 40, weight: .light))
                                    Text("Add your photos").font(.system(size: 15, weight: .semibold))
                                }.foregroundColor(Brand.ink)
                            }
                        }.buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity).aspectRatio(4 / 5, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(nameLine).font(.display(32)).foregroundColor(Brand.ink)
                ClubIdentityCard(club: store.profile.club, onEdit: { editing = true })
                if let me = Backend.shared.currentUserId?.uuidString {
                    MomentsSection(userId: me, isMe: true)
                }
                MediaGallery(items: Array((store.profile.media ?? []).dropFirst()))

                HStack(spacing: 10) {
                    Button { FX.tap(); editing = true } label: {
                        Label("Edit profile", systemImage: "pencil").frame(maxWidth: .infinity)
                    }.buttonStyle(PrimaryButtonStyle())
                    Button { FX.tap(); settings = true } label: {
                        Image(systemName: "gearshape.fill").font(.system(size: 17, weight: .semibold)).foregroundColor(Brand.ink)
                            .frame(width: 54, height: 54).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Brand.bg)
        .sheet(isPresented: $editing) { NavigationStack { EditProfileView() }.environmentObject(store) }
        .sheet(isPresented: $settings) { SettingsView().environmentObject(store) }
    }
}

// MARK: - Identidad del club en el perfil

/// Tarjeta «quién es esta persona»: bio, estancia en Bali, barrio, de dónde es,
/// deportes y qué busca. La MISMA para el perfil propio y el ajeno (fuente única).
/// Con `onEdit` es el perfil propio: lápiz para editar y, si está vacía, invitación a
/// rellenarla en vez de desaparecer (sin identidad no hay nada que enseñar en Discover).
struct ClubIdentityCard: View {
    let club: ClubIdentity
    var onEdit: (() -> Void)? = nil

    var body: some View {
        if club.isEmpty {
            if let onEdit { emptyInvite(onEdit) }
        } else {
            PanelCard {
                HStack(alignment: .top) {
                    if let bio = club.trimmedBio {
                        Text(bio).font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if let onEdit {
                        Button { FX.tap(); onEdit() } label: {
                            Image(systemName: "pencil").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.soft)
                                .frame(width: 30, height: 30).background(Brand.chip).clipShape(Circle())
                        }.buttonStyle(.plain)
                    }
                }
                facts
                if !club.sportList.isEmpty {
                    WrapLayout(spacing: 6) {
                        ForEach(club.sportList) { s in chip("\(s.emoji) \(s.label)") }
                    }
                }
                if !club.intentList.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("OPEN TO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
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
        }
    }

    /// Estancia primero: es lo que más cambia la utilidad de conectar con alguien.
    @ViewBuilder
    private var facts: some View {
        let stay = club.stay
        let home = club.homeLine
        if stay != nil || club.area != nil || home != nil {
            VStack(alignment: .leading, spacing: 7) {
                if let stay {
                    HStack(spacing: 8) {
                        fact(stayIcon(stay.kind), stay.headline)
                        if let u = stay.urgency {
                            Text(u).font(.system(size: 11, weight: .heavy)).foregroundColor(Brand.redText)
                                .padding(.horizontal, 8).frame(height: 22).background(Brand.redSoft).clipShape(Capsule())
                        }
                    }
                }
                if let a = club.area { fact("mappin.and.ellipse", a.label) }
                if let home { fact("globe.europe.africa.fill", String(format: L10n.t("From %@"), home)) }
            }
        }
    }

    private func stayIcon(_ k: StayKind) -> String {
        switch k {
        case .livingHere: return "house.fill"
        case .longTerm:   return "calendar"
        case .until:      return "airplane.departure"
        }
    }

    private func fact(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.bronze).frame(width: 18)
            Text(text).font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.ink)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
            .padding(.horizontal, 11).frame(height: 30).background(Brand.chip).clipShape(Capsule())
    }

    private func emptyInvite(_ onEdit: @escaping () -> Void) -> some View {
        PanelCard {
            Text("Tell the club who you are").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
            Text("Add a bio, your sports, where you're based and how long you're around. It's what people see before they connect.")
                .font(.footnote).foregroundColor(Brand.muted).fixedSize(horizontal: false, vertical: true)
            Button { FX.tap(); onEdit() } label: {
                Text("Complete your profile")
            }.buttonStyle(PrimaryButtonStyle())
        }
    }
}

/// Fila que salta de línea cuando no cabe (chips de longitud variable). `LazyVGrid`
/// obliga a columnas de ancho fijo y deja «Beach volleyball» cortado junto a «BJJ».
struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var cur = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = cur.indices.isEmpty ? size.width : cur.width + spacing + size.width
            if needed > width, !cur.indices.isEmpty {
                rows.append(cur); cur = Row()
            }
            cur.width = cur.indices.isEmpty ? size.width : cur.width + spacing + size.width
            cur.height = max(cur.height, size.height)
            cur.indices.append(i)
        }
        if !cur.indices.isEmpty { rows.append(cur) }
        return rows
    }
}
