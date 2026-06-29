import SwiftUI
import MapKit

private struct RankRow {
    let name: String
    let score: Int
    let isMe: Bool
    let emoji: String
    let flag: String
    var personId: String? = nil
}

private struct MapPlace: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let isMe: Bool
    let person: SocialPerson?
}

struct RankingView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var location = LocationManager()
    @State private var scope = 0 // 0 amigos,1 global,2 país,3 ciudad,4 zona
    @State private var selectedMapPerson: SocialPerson?
    @State private var profileTarget: IdString?
    @State private var showMap = false   // el Map de MapKit pide ubicación al crearse: lo diferimos hasta que el usuario lo abra
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))

    private let scopeNames = ["Amigos", "Global", "España", "Ciudad", "Zona"]
    private let scopeIcons = ["person.2.fill", "globe", "mappin.and.ellipse", "person.3.fill", "scope"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                rankingCard
                mapCard
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
        .onReceive(location.$coordinate.compactMap { $0 }) { coord in
            region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
        .sheet(item: $profileTarget) { item in
            if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
        }
    }

    private var rankingCard: some View {
        PanelCard {
            HStack {
                Text("Ranking").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                Spacer()
                Text(scopeNames[scope]).font(.caption).fontWeight(.heavy).foregroundColor(Brand.muted)
            }
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Button { scope = i } label: {
                        Image(systemName: scopeIcons[i]).font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background(scope == i ? Brand.greenSoft : Brand.chip)
                            .foregroundColor(Brand.ink).clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
            if scope == 0 && friendsRanking.count <= 1 {
                Text("Añade amigos para ver vuestro ranking.").font(.footnote).foregroundColor(Brand.muted)
            }
            ForEach(Array(rankingRows.enumerated()), id: \.offset) { idx, row in
                if let pid = row.personId {
                    Button { FX.tap(); profileTarget = IdString(id: pid) } label: { rankRow(idx, row) }
                        .buttonStyle(.plain)
                } else {
                    rankRow(idx, row)
                }
            }
        }
    }

    private func rankRow(_ idx: Int, _ row: RankRow) -> some View {
        HStack(spacing: 10) {
            Text("\(idx + 1)").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.muted).frame(width: 20)
            ZStack(alignment: .bottomTrailing) {
                if row.isMe { MeAvatar(account: store.account, size: 34) } else { Avatar(emoji: row.emoji, size: 34) }
                Text(row.flag).font(.system(size: 11))
                    .frame(width: 17, height: 17).background(Circle().fill(.white))
                    .overlay(Circle().stroke(Brand.line))
                    .offset(x: 3, y: 3)
            }
            Text(row.name).font(.system(size: 14, weight: row.isMe ? .heavy : .semibold)).foregroundColor(Brand.ink)
            Spacer()
            Text("\(row.score)").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(row.isMe ? Brand.greenSoft.opacity(0.4) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var mapCard: some View {
        PanelCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mapa").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(location.status).font(.caption).foregroundColor(Brand.muted)
                }
                Spacer()
                if showMap {
                    Button { location.request() } label: {
                        Label("Ubicarme", systemImage: "location.fill").font(.system(size: 13, weight: .heavy))
                            .padding(.horizontal, 12).frame(height: 34).background(Brand.greenSoft)
                            .foregroundColor(Brand.ink).clipShape(Capsule())
                    }
                }
            }
            if showMap {
                Map(coordinateRegion: $region, showsUserLocation: location.coordinate != nil, annotationItems: places) { place in
                    MapAnnotation(coordinate: place.coordinate) {
                        if place.isMe {
                            Text("Tú").font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4).background(Brand.ink).clipShape(Capsule())
                        } else if let person = place.person {
                            Button { FX.tap(); selectedMapPerson = person } label: {
                                Text(person.avatar).font(.system(size: 20))
                                    .frame(width: 40, height: 40).background(Color.white).clipShape(Circle())
                                    .overlay(Circle().stroke(Brand.green, lineWidth: 2))
                                    .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                            }
                        }
                    }
                }
                .frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 12))
                Text("Toca un usuario para ver su perfil. Ubicaciones aproximadas.")
                    .font(.caption2).foregroundColor(Brand.soft)
            } else {
                Button { FX.tap(); showMap = true; location.request() } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "map.fill").font(.system(size: 30)).foregroundColor(Color(hex: "6ea300"))
                        Text("Ver mapa de la comunidad").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                        Text("Descubre atletas cerca de ti").font(.caption).foregroundColor(Brand.muted)
                    }
                    .frame(maxWidth: .infinity).frame(height: 160)
                    .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Brand.line))
                }.buttonStyle(.plain)
            }
        }
        .sheet(item: $selectedMapPerson) { MapUserSheet(person: $0).environmentObject(store) }
    }

    private var anchor: CLLocationCoordinate2D {
        location.coordinate ?? CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
    }

    private var places: [MapPlace] {
        var list = store.people.prefix(6).map { p -> MapPlace in
            var seed: UInt64 = 0
            for ch in p.id.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
            let r1 = Double(seed % 1000) / 1000.0
            let r2 = Double((seed / 1000) % 1000) / 1000.0
            return MapPlace(
                id: p.id,
                coordinate: .init(latitude: anchor.latitude + (r1 - 0.5) * 0.02,
                                  longitude: anchor.longitude + (r2 - 0.5) * 0.02),
                isMe: false, person: p)
        }
        if location.coordinate != nil {
            list.append(MapPlace(id: "me", coordinate: anchor, isMe: true, person: nil))
        }
        return list
    }

    private var meRow: RankRow {
        RankRow(name: "Tú", score: store.gymScore.total, isMe: true, emoji: "🙂", flag: countryFlag(store.profile.country))
    }

    private var friendsRanking: [RankRow] {
        let friends = store.people.filter { store.relationship($0.id) == .friends }
        var rows = friends.map { p in
            RankRow(name: p.name, score: GymScoreEngine.calculate(buildFriendHistory(p)).total, isMe: false, emoji: p.avatar, flag: p.flag, personId: p.id)
        }
        rows.append(meRow)
        return rows.sorted { $0.score > $1.score }
    }

    private var rankingRows: [RankRow] {
        if scope == 0 { return friendsRanking }
        let base = store.gymScore.total == 0 ? 42 : store.gymScore.total
        let names = [["Mika", "Leo", "Sofía", "Tú", "Alex", "Nora"],
                     ["Dani", "Carlos", "Tú", "Marina", "Iker", "Luna"],
                     ["Rafa", "Tú", "Julia", "Adri", "Vera", "Noa"],
                     ["Tú", "Pablo", "Marta", "Hugo", "Laia", "Enzo"]][scope - 1]
        let offsets = [[24, 16, 9, 0, -4, -11], [13, 6, 0, -5, -9, -14], [8, 0, -3, -7, -12, -16], [0, -2, -6, -10, -13, -18]][scope - 1]
        let emojis = ["🦊", "🐻", "🦅", "🐺", "🦌", "🦁"]
        let globalFlags = ["🇺🇸", "🇲🇽", "🇬🇧", "🇫🇷", "🇩🇪", "🇮🇹"]
        return zip(names, offsets).enumerated().map { idx, pair in
            let (name, off) = pair
            if name == "Tú" { return RankRow(name: "Tú", score: max(0, min(100, base + off)), isMe: true, emoji: "🙂", flag: countryFlag(store.profile.country)) }
            let flag = scope == 1 ? globalFlags[idx % globalFlags.count] : "🇪🇸"
            let pid = store.people.first { $0.name == name }?.id
            return RankRow(name: name, score: max(0, min(100, base + off)), isMe: false, emoji: emojis[idx % emojis.count], flag: flag, personId: pid)
        }.sorted { $0.score > $1.score }
    }
}

struct MapUserSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let person: SocialPerson
    @State private var showProfile = false

    var body: some View {
        let status = store.relationship(person.id)
        let score = GymScoreEngine.calculate(buildFriendHistory(person)).total
        return NavigationStack {
            VStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Avatar(emoji: person.avatar, size: 80)
                    Text(person.flag).font(.system(size: 16)).frame(width: 24, height: 24)
                        .background(Circle().fill(.white)).overlay(Circle().stroke(Brand.line)).offset(x: 4, y: 4)
                }
                VStack(spacing: 3) {
                    Text(person.name).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("@\(person.handle)").font(.subheadline).foregroundColor(Brand.muted)
                }
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill").foregroundColor(Color(hex: "6ea300"))
                    Text(person.gym).font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "3f4837"))
                }
                Text("Gym Score \(score)").font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                    .padding(.horizontal, 12).padding(.vertical, 5).background(Brand.greenSoft).clipShape(Capsule())

                Button { showProfile = true } label: { Label("Ver perfil", systemImage: "person.crop.circle") }
                    .buttonStyle(PrimaryButtonStyle())

                friendAction(status)
                Spacer()
            }
            .padding(20)
            .background(Brand.bg)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showProfile) { FriendProfileView(person: person).environmentObject(store) }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func friendAction(_ status: RelationshipStatus) -> some View {
        switch status {
        case .none:
            Button { FX.tap(); store.followOrRequest(person.id) } label: {
                Label("Seguir", systemImage: "person.badge.plus").font(.system(size: 15, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                    .frame(maxWidth: .infinity).frame(minHeight: 48).background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .outgoing:
            Button { FX.tap(); store.followOrRequest(person.id) } label: {
                Label("Pendiente", systemImage: "clock").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    .frame(maxWidth: .infinity).frame(minHeight: 48).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .incoming:
            Button { FX.success(sound: true); store.acceptFriendRequest(person.id) } label: {
                Label("Aceptar solicitud", systemImage: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    .frame(maxWidth: .infinity).frame(minHeight: 48).background(Brand.greenSoft).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .friends:
            Button { FX.tap(); store.followOrRequest(person.id) } label: {
                Label("Siguiendo", systemImage: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                    .frame(maxWidth: .infinity).frame(minHeight: 48).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
