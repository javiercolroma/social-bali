import SwiftUI

/// Búsqueda de usuarios REALES (Supabase) por @usuario + seguir/dejar de seguir.
/// Escribe en la tabla `follows` real. Es la primera superficie del grafo social real
/// (la que habilita feed/chat reales); convive con la UI demo existente.
struct DiscoverPeopleView: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    @State private var results: [ProfileRow] = []
    @State private var following: Set<String> = []
    @State private var loading = false
    @State private var searched = false
    @State private var searchTask: Task<Void, Never>?
    @State private var profileTarget: IdString?   // perfil a previsualizar (toca avatar/nombre)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(Brand.soft)
                    TextField("Buscar por @usuario o nombre", text: $query)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.search)
                        .onChange(of: query) { _ in scheduleSearch() }
                    if !query.isEmpty {
                        Button { query = ""; results = []; searched = false } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Brand.soft)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).frame(height: 50).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))

                if loading {
                    ProgressView().padding(.top, 24)
                } else if searched && results.isEmpty {
                    Text("No hay nadie con «\(query)».").font(.footnote).foregroundColor(Brand.muted).padding(.top, 24)
                } else if !searched {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.badge.plus").font(.system(size: 34)).foregroundColor(Brand.soft)
                        Text("Busca a otras personas por su @usuario y síguelas.")
                            .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                    }.padding(.top, 30)
                }

                ScrollView {
                    LazyVStack(spacing: 8) { ForEach(results, id: \.id) { row($0) } }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Brand.bg)
            .navigationTitle("Buscar personas").navigationBarTitleDisplayMode(.inline)
            .task { await loadFollowing() }
            .sheet(item: $profileTarget) { item in
                if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
            }
        }
    }

    private func row(_ p: ProfileRow) -> some View {
        // Postgres devuelve los UUID en minúscula; UUID.uuidString los da en mayúscula → normaliza.
        let uid = p.id.uuidString.lowercased()
        let isFollowing = following.contains(uid)
        return HStack(spacing: 12) {
            // Avatar + nombre TOCABLES: abren la previsualización del perfil (sigas o no a esa persona).
            Button { FX.tap(); profileTarget = IdString(id: uid) } label: {
                HStack(spacing: 12) {
                    if let a = p.avatar_url, let u = URL(string: a) {
                        AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { Brand.chip }
                            .frame(width: 44, height: 44).clipShape(Circle())
                    } else {
                        Avatar(emoji: "🙂", size: 44)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name ?? p.handle ?? "Usuario").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                        if let h = p.handle { Text("@\(h)").font(.caption).foregroundColor(Brand.muted) }
                    }
                }
            }.buttonStyle(.plain)
            Spacer()
            Button {
                FX.tap()
                let willFollow = !isFollowing
                if willFollow { following.insert(uid) } else { following.remove(uid) }
                Task {
                    do {
                        if willFollow {
                            // Cuentas privadas → solicitud (el server igual lo fuerza a 'pending').
                            try await Backend.shared.setFollow(p.id, status: (p.is_private ?? false) ? "pending" : "accepted")
                        } else {
                            try await Backend.shared.unfollow(p.id)
                        }
                        store.loadFollowing()   // refresca "tus amigos" con el follow real
                    } catch {
                        // Falló la red → revierte el estado optimista.
                        if willFollow { following.remove(uid) } else { following.insert(uid) }
                    }
                }
            } label: {
                Text(isFollowing ? "Siguiendo" : "Seguir")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(isFollowing ? Brand.ink : Color(hex: "10150a"))
                    .padding(.horizontal, 16).frame(height: 36)
                    .background(isFollowing ? Brand.chip : Brand.green)
                    .clipShape(Capsule())
            }.buttonStyle(.plain)
        }
        .padding(10).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Búsqueda en vivo mientras se escribe, con un pequeño retardo (debounce) para
    /// no lanzar una petición por cada tecla. Cancela la búsqueda anterior.
    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; searched = false; loading = false; return }
        loading = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let r = (try? await Backend.shared.searchProfiles(q)) ?? []
            if Task.isCancelled { return }
            // ASYNC: el id síncrono es nil en arranque frío (sesión aún restaurando) y
            // te aparecías tú mismo como "persona a seguir".
            let meId = await Backend.shared.currentUserIdAsync()
            results = r.filter { $0.id != meId }
            await loadFollowing()   // re-asegura el estado "Siguiendo" (evita ver «Seguir» en gente que ya sigues)
            loading = false; searched = true
        }
    }

    private func loadFollowing() async {
        let f = (try? await Backend.shared.fetchFollowing()) ?? []
        following = Set(f.map { $0.following_id.lowercased() })
    }
}
