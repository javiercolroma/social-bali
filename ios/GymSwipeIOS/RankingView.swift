import SwiftUI
import MapKit

private struct RankRow {
    let name: String
    let score: Int
    let isMe: Bool
    let emoji: String
    let flag: String
}

private struct MapPlace: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let label: String
    let isMe: Bool
}

struct RankingView: View {
    @EnvironmentObject var store: AppStore
    @StateObject private var location = LocationManager()
    @State private var scope = 0 // 0 amigos,1 global,2 país,3 ciudad,4 zona
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))

    private let scopeNames = ["Amigos", "Global", "España", "Ciudad", "Zona"]
    private let scopeIcons = ["person.2.fill", "globe", "mappin.and.ellipse", "person.3.fill", "scope"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                gymScoreCard
                rankingCard
                mapCard
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
        .onReceive(location.$coordinate.compactMap { $0 }) { coord in
            region = MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
    }

    private var gymScoreCard: some View {
        let s = store.gymScore
        return PanelCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("GYM SCORE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    Text("\(s.total)").font(.system(size: 48, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(s.tier).font(.system(size: 12, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 10).padding(.vertical, 3).background(Brand.greenSoft).clipShape(Capsule())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(s.reliable ? "Fiable · \(s.reliability)%" : "Provisional")
                        .font(.system(size: 11, weight: .heavy)).foregroundColor(s.reliable ? Color(hex: "18320d") : Color(hex: "7a4d00"))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(s.reliable ? Color(hex: "dff0bf") : Color(hex: "ffe2a3")).clipShape(Capsule())
                    if !s.reliable {
                        Text("Faltan \(s.daysUntilReliable) días").font(.caption2).foregroundColor(Brand.soft)
                    }
                }
            }
            if !s.reliable {
                Text("Entrena 3 semanas para tu score real (potencial \(s.potential)).")
                    .font(.footnote).foregroundColor(Brand.muted)
            }
            VStack(spacing: 8) {
                ScoreBarView(label: "Fuerza", value: s.strength)
                ScoreBarView(label: "Constancia", value: s.consistency)
                ScoreBarView(label: "Progreso", value: s.progression)
                ScoreBarView(label: "Volumen", value: s.volume)
                ScoreBarView(label: "Calidad", value: s.quality)
                ScoreBarView(label: "Variedad", value: s.variety)
            }
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
        }
    }

    private var mapCard: some View {
        PanelCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mapa").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(location.status).font(.caption).foregroundColor(Brand.muted)
                }
                Spacer()
                Button { location.request() } label: {
                    Label("Ubicarme", systemImage: "location.fill").font(.system(size: 13, weight: .heavy))
                        .padding(.horizontal, 12).frame(height: 34).background(Brand.greenSoft)
                        .foregroundColor(Brand.ink).clipShape(Capsule())
                }
            }
            Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: places) { place in
                MapAnnotation(coordinate: place.coordinate) {
                    Text(place.isMe ? "Tú" : "•")
                        .font(.system(size: place.isMe ? 11 : 22, weight: .heavy))
                        .foregroundColor(place.isMe ? .white : Brand.green)
                        .padding(.horizontal, place.isMe ? 8 : 0).padding(.vertical, place.isMe ? 4 : 0)
                        .background(place.isMe ? Brand.ink : Color.clear).clipShape(Capsule())
                }
            }
            .frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Pellizca para hacer zoom. Usuarios aproximados, no ubicación exacta.")
                .font(.caption2).foregroundColor(Brand.soft)
        }
    }

    private var places: [MapPlace] {
        var list: [MapPlace] = [
            MapPlace(id: "u1", coordinate: .init(latitude: 40.43, longitude: -3.70), label: "Chamberí", isMe: false),
            MapPlace(id: "u2", coordinate: .init(latitude: 40.41, longitude: -3.68), label: "Retiro", isMe: false),
            MapPlace(id: "u3", coordinate: .init(latitude: 40.43, longitude: -3.71), label: "Malasaña", isMe: false),
            MapPlace(id: "u4", coordinate: .init(latitude: 40.42, longitude: -3.69), label: "Centro", isMe: false),
        ]
        if let c = location.coordinate {
            list.append(MapPlace(id: "me", coordinate: c, label: "Tú", isMe: true))
        }
        return list
    }

    private var meRow: RankRow {
        RankRow(name: "Tú", score: store.gymScore.total, isMe: true, emoji: "🙂", flag: countryFlag(store.profile.country))
    }

    private var friendsRanking: [RankRow] {
        let friends = store.people.filter { store.relationship($0.id) == .friends }
        var rows = friends.map { p in
            RankRow(name: p.name, score: GymScoreEngine.calculate(buildFriendHistory(p)).total, isMe: false, emoji: p.avatar, flag: p.flag)
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
            return RankRow(name: name, score: max(0, min(100, base + off)), isMe: false, emoji: emojis[idx % emojis.count], flag: flag)
        }.sorted { $0.score > $1.score }
    }
}
