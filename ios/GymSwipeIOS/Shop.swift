import SwiftUI

// MARK: - Cosméticos y tienda

struct ShopItem: Identifiable {
    let id: String
    let name: String
    let price: Int
    var colors: [String] = []     // marcos de avatar
    var forgey: String? = nil     // id de accesorio de Forgey
}

enum Cosmetics {
    static let frames: [ShopItem] = [
        ShopItem(id: "aro-oro",     name: "Aro Oro",     price: 150, colors: ["f3cf5c", "d19a12"]),
        ShopItem(id: "aro-cian",    name: "Aro Cian",    price: 150, colors: ["6fe3ec", "1f9fb0"]),
        ShopItem(id: "aro-fuego",   name: "Aro Fuego",   price: 220, colors: ["ffb03a", "f2600c"]),
        ShopItem(id: "aro-violeta", name: "Aro Violeta", price: 220, colors: ["c79bff", "7b3ff2"]),
        ShopItem(id: "aro-neon",    name: "Aro Neón",    price: 300, colors: ["d4ff5c", "6fd000"]),
    ]
    static let forgey: [ShopItem] = [
        ShopItem(id: "corona",      name: "Corona",      price: 250, forgey: "corona"),
        ShopItem(id: "gorro",       name: "Gorro grad.", price: 180, forgey: "gorro"),
        ShopItem(id: "auriculares", name: "Auriculares", price: 180, forgey: "auriculares"),
        ShopItem(id: "aureola",     name: "Aureola",     price: 320, forgey: "aureola"),
    ]
    static let freezePrice = 120

    static func frameColors(_ id: String?) -> [String]? {
        guard let id else { return nil }
        return frames.first { $0.id == id }?.colors
    }
    static func forgeyAccessory(_ id: String?) -> String? {
        guard let id else { return nil }
        return forgey.first { $0.id == id }?.forgey
    }
}

// MARK: - Títulos (se ganan, no se compran)

struct Title: Identifiable {
    let id: String        // el propio texto del título
    let detail: String
    let unlocked: @MainActor (AppStore) -> Bool
}

enum Titles {
    static let all: [Title] = [
        Title(id: "Novato", detail: "Te damos la bienvenida", unlocked: { _ in true }),
        Title(id: "Constante", detail: "Guarda 10 entrenos", unlocked: { $0.sessions.count >= 10 }),
        Title(id: "Bestia constante", detail: "Racha de 14", unlocked: { $0.player.streak >= 14 || $0.streakMilestones.contains(14) }),
        Title(id: "Rompe-récords", detail: "Bate 5 récords", unlocked: { $0.prCount >= 5 }),
        Title(id: "Rey de la pierna", detail: "1RM de pierna ≥ 150 kg", unlocked: { s in
            s.personalBests.contains { (k, v) in (k.contains("sentadilla") || k.contains("peso muerto") || k.contains("prensa")) && v.e1rm >= 150 }
        }),
        Title(id: "Maestro del hierro", detail: "Llega a división Maestro", unlocked: { $0.gymScore.total >= 90 }),
        Title(id: "Leyenda", detail: "Llega a la Liga Leyenda", unlocked: { $0.leagueTier >= League.maxTier }),
    ]
}

extension AppStore {
    func owns(_ id: String) -> Bool { ownedCosmetics.contains(id) }
    func buyCosmetic(_ item: ShopItem) {
        guard !owns(item.id), coins >= item.price else { return }
        coins -= item.price; ownedCosmetics.insert(item.id); FX.success(sound: true); persist()
    }
    func buyFreeze() {
        guard coins >= Cosmetics.freezePrice else { return }
        coins -= Cosmetics.freezePrice; streakFreezes += 1; FX.success(sound: true); persist()
    }
    func equipFrame(_ id: String) { equippedFrame = (equippedFrame == id) ? nil : id; FX.tap(); persist() }
    func equipForgey(_ id: String) { equippedForgey = (equippedForgey == id) ? nil : id; FX.tap(); persist() }
    func titleUnlocked(_ t: Title) -> Bool { t.unlocked(self) }
    func equipTitle(_ id: String?) { equippedTitle = id; FX.tap(); persist() }
}

// MARK: - Marco de avatar

struct AvatarFrame: View {
    let frameId: String?
    let size: CGFloat
    var body: some View {
        if let cols = Cosmetics.frameColors(frameId) {
            Circle()
                .stroke(LinearGradient(colors: cols.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: max(2.5, size * 0.06))
                .frame(width: size, height: size)
                .shadow(color: Color(hex: cols[0]).opacity(0.6), radius: size * 0.06)
        }
    }
}

// MARK: - Tienda

struct ShopView: View {
    @EnvironmentObject var store: AppStore
    private let cols = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text("Gasta tus monedas").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                        Spacer()
                        HStack(spacing: 5) { Text("🪙"); Text("\(store.coins)").font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink) }
                            .padding(.horizontal, 12).frame(height: 40).background(Brand.chip).clipShape(Capsule())
                    }

                    // Forgey — vista previa con el accesorio equipado
                    section("FORGEY") {
                        Mascot(size: 92, accessory: Cosmetics.forgeyAccessory(store.equippedForgey))
                            .frame(height: 120)
                        LazyVGrid(columns: cols, spacing: 12) {
                            ForEach(Cosmetics.forgey) { item in
                                shopTile(item, isForgey: true,
                                         swatch: AnyView(Image(systemName: Mascot.accessory(item.forgey ?? "")?.symbol ?? "star.fill")
                                            .font(.system(size: 26, weight: .heavy)).foregroundColor(Brand.ink)))
                            }
                        }
                    }

                    // Marcos de avatar
                    section("MARCOS DE AVATAR") {
                        LazyVGrid(columns: cols, spacing: 12) {
                            ForEach(Cosmetics.frames) { item in
                                shopTile(item, isForgey: false,
                                         swatch: AnyView(ZStack {
                                            Avatar(emoji: "🙂", size: 46)
                                            AvatarFrame(frameId: item.id, size: 52)
                                         }))
                            }
                        }
                    }

                    // Consumibles
                    section("CONSUMIBLES") {
                        HStack(spacing: 12) {
                            Text("🧊").font(.system(size: 34))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Congelador de racha").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                                Text("Protege tu racha un día. Tienes \(store.streakFreezes).").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft)
                            }
                            Spacer()
                            Button { withAnimation { store.buyFreeze() } } label: {
                                Text("🪙 \(Cosmetics.freezePrice)").font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                    .padding(.horizontal, 12).frame(height: 36)
                                    .background(store.coins >= Cosmetics.freezePrice ? Brand.green : Brand.chip).clipShape(Capsule())
                            }.buttonStyle(.plain).disabled(store.coins < Cosmetics.freezePrice)
                        }
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Tienda").navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
    }

    private func shopTile(_ item: ShopItem, isForgey: Bool, swatch: AnyView) -> some View {
        let owned = store.owns(item.id)
        let equipped = isForgey ? (store.equippedForgey == item.id) : (store.equippedFrame == item.id)
        return VStack(spacing: 8) {
            swatch.frame(height: 54)
            Text(item.name).font(.system(size: 12, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
            if owned {
                Button {
                    if isForgey { store.equipForgey(item.id) } else { store.equipFrame(item.id) }
                } label: {
                    Text(equipped ? "Equipado" : "Equipar").font(.system(size: 12, weight: .heavy))
                        .foregroundColor(equipped ? Color(hex: "10150a") : Brand.ink)
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(equipped ? Brand.green : Brand.chip).clipShape(Capsule())
                }.buttonStyle(.plain)
            } else {
                Button { withAnimation { store.buyCosmetic(item) } } label: {
                    Text("🪙 \(item.price)").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(store.coins >= item.price ? Brand.green : Brand.chip).clipShape(Capsule())
                }.buttonStyle(.plain).disabled(store.coins < item.price)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 8)
        .background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(equipped ? Brand.green : Brand.line, lineWidth: equipped ? 2 : 1))
    }
}

// MARK: - Títulos

struct TitlesView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Titles.all) { t in
                        let unlocked = store.titleUnlocked(t)
                        let equipped = store.equippedTitle == t.id
                        Button {
                            guard unlocked else { return }
                            store.equipTitle(equipped ? nil : t.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: unlocked ? "seal.fill" : "lock.fill")
                                    .font(.system(size: 20)).foregroundColor(unlocked ? Color(hex: "e2a915") : Brand.soft)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.id).font(.system(size: 15, weight: .heavy)).foregroundColor(unlocked ? Brand.ink : Brand.muted)
                                    Text(t.detail).font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft)
                                }
                                Spacer()
                                if equipped { Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundColor(Brand.green) }
                            }
                            .padding(14).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(equipped ? Brand.green : Brand.line, lineWidth: equipped ? 2 : 1))
                            .opacity(unlocked ? 1 : 0.7)
                        }.buttonStyle(.plain).disabled(!unlocked)
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Títulos").navigationBarTitleDisplayMode(.inline)
        }
    }
}
