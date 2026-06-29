import SwiftUI
import PhotosUI

func normalizeHandle(_ value: String) -> String {
    let lower = value.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    let filtered = lower.unicodeScalars.filter { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_").contains($0) }
    return String(String.UnicodeScalarView(filtered)).prefix(20).description
}

// MARK: - Messages

struct MessagesSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var initialTab: Int = 0
    @State private var tab = 0
    @State private var profileTarget: IdString?
    @State private var chatTarget: IdString?
    var onOpenChat: (String) -> Void
    var onOpenProfile: (String) -> Void
    var onEditAccount: () -> Void

    private var conversations: [Conversation] { store.conversations.sorted { $0.lastAt > $1.lastAt } }
    private var incoming: [SocialPerson] { store.people.filter { store.relationship($0.id) == .incoming } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker("", selection: $tab) {
                    Text(incoming.isEmpty ? "Amigos" : "Amigos (\(incoming.count))").tag(0)
                    Text("Mensajes").tag(1)
                }.pickerStyle(.segmented).padding(.horizontal, 16)

                ScrollView {
                    if tab == 1 { chats } else {
                        FriendsContent(onOpenChat: { chatTarget = IdString(id: $0) },
                                       onOpenProfile: { profileTarget = IdString(id: $0) },
                                       onEditAccount: onEditAccount)
                    }
                }
            }
            .padding(.top, 8)
            .background(Brand.bg)
            .navigationTitle("Mensajes").navigationBarTitleDisplayMode(.inline)
            .onAppear { tab = initialTab }
            .sheet(item: $profileTarget) { item in
                if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
            }
        }
        // Chat dentro de Mensajes: al volver, regresas a Amigos/Mensajes (no a Social).
        .overlay {
            if let c = chatTarget {
                ChatView(personId: c.id, onOpenProfile: { _ in }, onClose: { chatTarget = nil })
                    .environmentObject(store)
                    .transition(.move(edge: .trailing))
                    .zIndex(5)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: chatTarget?.id)
    }

    private var chats: some View {
        VStack(spacing: 8) {
            if conversations.isEmpty {
                emptyState(icon: "tray", title: "Sin conversaciones", body: "Acepta un entrenamiento o escribe a un amigo.")
            } else {
                ForEach(conversations) { conv in
                    let person = store.person(conv.personId)
                    Button { chatTarget = IdString(id: conv.personId) } label: {
                        HStack(spacing: 11) {
                            Avatar(emoji: person?.avatar ?? "👤")
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(person?.name ?? "Compañero").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                                    Spacer()
                                    if let m = conv.lastMessage { Text(shortTime(m.at)).font(.caption2).foregroundColor(Brand.soft) }
                                }
                                HStack {
                                    Text(previewText(conv)).font(.system(size: 13)).foregroundColor(conv.unread > 0 ? Brand.ink : Brand.muted)
                                        .lineLimit(1)
                                    Spacer()
                                    if conv.unread > 0 {
                                        Text("\(conv.unread)").font(.system(size: 11, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                                            .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20).background(Brand.green).clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(12).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(.horizontal, 14).padding(.bottom, 16)
    }

    private func previewText(_ conv: Conversation) -> String {
        guard let m = conv.lastMessage else { return "Sin mensajes todavía" }
        return (m.fromMe ? "Tú: " : "") + m.text
    }
}

func emptyState(icon: String, title: String, body: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon).font(.system(size: 26)).foregroundColor(Brand.soft)
        Text(title).font(.system(size: 16, weight: .heavy)).foregroundColor(Color(hex: "41463c"))
        Text(body).font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
    }.padding(.top, 60).padding(.horizontal, 30).frame(maxWidth: .infinity)
}

// MARK: - Friends

struct FriendsContent: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    var onOpenChat: (String) -> Void
    var onOpenProfile: (String) -> Void
    var onEditAccount: () -> Void

    private func rel(_ id: String) -> RelationshipStatus { store.relationship(id) }
    private var incoming: [SocialPerson] { store.people.filter { rel($0.id) == .incoming } }
    private var friends: [SocialPerson] { store.people.filter { rel($0.id) == .friends } }
    private var discover: [SocialPerson] { store.people.filter { rel($0.id) == .none || rel($0.id) == .outgoing } }
    private var results: [SocialPerson] {
        let q = query.folding(options: .diacriticInsensitive, locale: .current).lowercased().replacingOccurrences(of: "@", with: "")
        guard !q.isEmpty else { return [] }
        return store.people.filter {
            $0.name.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(q) || $0.handle.contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(Brand.soft)
                TextField("Buscar por nombre o @usuario", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Brand.soft) } }
            }
            .padding(.horizontal, 12).frame(height: 44).background(Color.white).clipShape(Capsule())
            .overlay(Capsule().stroke(Brand.line))

            if !query.isEmpty {
                section("Resultados", people: results, empty: "Nadie coincide con “\(query)”.")
            } else {
                section("Solicitudes recibidas", people: incoming, empty: "Sin solicitudes pendientes.")
                section("Tus amigos", people: friends, empty: "Aún no tienes amigos. Busca arriba.")
                section("Descubre compañeros", people: discover, empty: "Ya estás conectado con todos.")
            }
        }.padding(.horizontal, 14).padding(.bottom, 16)
    }

    private func section(_ title: String, people: [SocialPerson], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            if people.isEmpty {
                Text(empty).font(.footnote).foregroundColor(Brand.muted)
            } else {
                ForEach(people) { person in personRow(person) }
            }
        }
    }

    private func personRow(_ person: SocialPerson) -> some View {
        let status = rel(person.id)
        return HStack(spacing: 11) {
            Button { onOpenProfile(person.id) } label: {
                HStack(spacing: 11) {
                    Avatar(emoji: person.avatar)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(person.name).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                        Text("@\(person.handle)").font(.caption).foregroundColor(Brand.muted)
                    }
                }
            }.buttonStyle(.plain)
            Spacer()
            switch status {
            case .incoming:
                Button { FX.success(sound: true); store.acceptFriendRequest(person.id) } label: { Image(systemName: "checkmark").foregroundColor(Color(hex: "10150a")) }
                    .frame(width: 36, height: 36).background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 10))
                Button { FX.warning(); store.rejectFriendRequest(person.id) } label: { Image(systemName: "xmark").foregroundColor(Color(hex: "a73232")) }
                    .frame(width: 36, height: 36).background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 10))
            case .friends:
                Button { FX.tap(); onOpenChat(person.id) } label: { Label("Mensaje", systemImage: "message.fill").font(.system(size: 12, weight: .heavy)) }
            case .outgoing:
                Button { FX.tap(); store.followOrRequest(person.id) } label: {
                    Label("Pendiente", systemImage: "clock").font(.system(size: 12, weight: .heavy)).foregroundColor(Brand.ink)
                }
            case .none:
                Button { FX.tap(); store.followOrRequest(person.id) } label: { Label("Seguir", systemImage: "person.badge.plus").font(.system(size: 12, weight: .heavy)) }
            }
        }
        .padding(10).background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }
}

// MARK: - Chat

struct ChatView: View {
    @EnvironmentObject var store: AppStore
    let personId: String
    var onOpenProfile: (String) -> Void
    var onClose: () -> Void = {}
    @State private var draft = ""
    @State private var profileTarget: IdString?

    private var person: SocialPerson? { store.person(personId) }
    private var conversation: Conversation? { store.conversations.first { $0.personId == personId } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button { onClose() } label: { Image(systemName: "arrow.left").font(.system(size: 18, weight: .semibold)).foregroundColor(Brand.ink) }
                Button { profileTarget = IdString(id: personId) } label: {
                    HStack(spacing: 11) {
                        Avatar(emoji: person?.avatar ?? "👤")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(person?.name ?? "Compañero").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                            Text(person?.gym ?? "").font(.caption).foregroundColor(Brand.muted)
                        }
                    }
                }.buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Brand.bg).overlay(Divider(), alignment: .bottom)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if let msgs = conversation?.messages, !msgs.isEmpty {
                            ForEach(msgs) { m in bubble(m).id(m.id) }
                        } else {
                            emptyState(icon: "message", title: "Sin mensajes", body: "Escribe el primer mensaje.")
                        }
                    }.padding(16)
                }
                .onChange(of: conversation?.messages.count ?? 0) { _ in
                    if let last = conversation?.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    store.markConversationRead(personId)
                }
            }

            HStack(spacing: 8) {
                TextField("Escribe un mensaje", text: $draft)
                    .padding(.horizontal, 16).frame(height: 46).background(Color.white).clipShape(Capsule())
                    .overlay(Capsule().stroke(Brand.line))
                Button { send() } label: {
                    Image(systemName: "paperplane.fill").foregroundColor(Color(hex: "10150a"))
                        .frame(width: 46, height: 46).background(Brand.green).clipShape(Circle())
                }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Brand.bg).overlay(Divider(), alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.bg.ignoresSafeArea())
        .onAppear { store.openConversation(personId) }
        .sheet(item: $profileTarget) { item in
            if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
        }
    }

    private func send() {
        guard !draft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        FX.tap()
        store.sendMessage(personId, draft, activeConversation: conversationId(personId))
        draft = ""
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.fromMe { Spacer(minLength: 50) }
            VStack(alignment: m.fromMe ? .trailing : .leading, spacing: 2) {
                Text(m.text).font(.system(size: 15)).foregroundColor(m.fromMe ? Color(hex: "10150a") : Color(hex: "2c3127"))
                Text(shortTime(m.at)).font(.system(size: 10, weight: .semibold)).opacity(0.5)
            }
            .padding(.horizontal, 11).padding(.vertical, 8)
            .background(m.fromMe ? Brand.greenSoft : Brand.chip)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if !m.fromMe { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Notifications

struct NotificationsSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var profileTarget: IdString?
    var onOpenChat: (String) -> Void
    var onOpenFriends: () -> Void

    private var sorted: [AppNotification] { store.notifications.sorted { $0.at > $1.at } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if sorted.isEmpty {
                        emptyState(icon: "bell", title: "Sin notificaciones", body: "Aquí verás solicitudes y entrenos aceptados.")
                    } else {
                        ForEach(sorted) { n in row(n) }
                    }
                }.padding(14)
            }
            .background(Brand.bg)
            .navigationTitle("Notificaciones").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $profileTarget) { item in
                if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
            }
        }
        // Al abrir, dejan de ser "nuevas" (ya las has visto), como en Instagram.
        .onAppear { store.markAllNotificationsRead() }
    }

    private func row(_ n: AppNotification) -> some View {
        let isPendingRequest = n.type == .friendRequest && n.personId.map { store.relationship($0) == .incoming } ?? false
        return VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                leadingIcon(n)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(n.title).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                        Spacer()
                        Text(relativeTime(n.at)).font(.caption2).foregroundColor(Brand.soft)
                    }
                    Text(n.body).font(.footnote).foregroundColor(Brand.muted)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.markNotificationRead(n.id)
                if let pid = n.personId {
                    if n.conversationId != nil { dismiss(); onOpenChat(pid) }
                    else { profileTarget = IdString(id: pid) }
                }
            }
            if isPendingRequest, let pid = n.personId {
                HStack(spacing: 8) {
                    Button { FX.success(); store.acceptFriendRequest(pid) } label: {
                        Text("Aceptar").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                            .frame(maxWidth: .infinity).frame(height: 38).background(Brand.green).clipShape(Capsule())
                    }.buttonStyle(.plain)
                    Button { FX.warning(); store.rejectFriendRequest(pid) } label: {
                        Text("Rechazar").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(maxWidth: .infinity).frame(height: 38).background(Brand.redSoft).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }

    /// Foto de perfil de la persona (con badge del tipo) si la notificación es de alguien; si no, icono genérico.
    @ViewBuilder
    private func leadingIcon(_ n: AppNotification) -> some View {
        if let pid = n.personId, let p = store.person(pid) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(emoji: p.avatar, size: 42)
                Image(systemName: icon(n.type)).font(.system(size: 9, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                    .frame(width: 18, height: 18).background(Brand.green).clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5)).offset(x: 3, y: 3)
            }
        } else {
            Image(systemName: icon(n.type)).font(.system(size: 15))
                .frame(width: 42, height: 42).background(Brand.greenSoft).foregroundColor(Color(hex: "10150a")).clipShape(Circle())
        }
    }

    private func icon(_ t: NotificationType) -> String {
        switch t {
        case .friendRequest: return "person.badge.plus"
        case .friendAccepted: return "checkmark"
        case .trainingAccepted: return "dumbbell.fill"
        case .newFollower: return "person.fill.badge.plus"
        }
    }
}

// MARK: - Friend profile

struct FriendProfileView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let person: SocialPerson
    @State private var daySheet: DayPayload?
    @State private var detailSession: WorkoutSession?

    var body: some View {
        let history = buildFriendHistory(person)
        let score = GymScoreEngine.calculate(history)
        let sessionsList = friendSessions(history)

        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    HStack(spacing: 10) {
                        statTile("GYM SCORE", "\(score.total)")
                        statTile("RACHA", "\(score.trainingDays) 🔥")
                    }
                    PanelCard {
                        Text(score.tier).font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                            .padding(.horizontal, 10).padding(.vertical, 3).background(Brand.greenSoft).clipShape(Capsule())
                        ScoreBarView(label: "Fuerza", value: score.strength)
                        ScoreBarView(label: "Constancia", value: score.consistency)
                        ScoreBarView(label: "Progreso", value: score.progression)
                        ScoreBarView(label: "Volumen", value: score.volume)
                        ScoreBarView(label: "Calidad", value: score.quality)
                        ScoreBarView(label: "Variedad", value: score.variety)
                    }
                    TrainingCalendarView(sessions: sessionsList) { date, day in
                        daySheet = DayPayload(id: date, date: date, sessions: day)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ENTRENOS · \(sessionsList.count)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(sessionsList) { s in sessionPostCard(s) }
                    }
                }.padding(16)
            }
            .background(Brand.bg)
            .navigationTitle(person.name).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $daySheet) { DaySessionsSheet(date: $0.date, sessions: $0.sessions, author: person).environmentObject(store) }
            .sheet(item: $detailSession) { s in
                ActivityDetailView(item: personActivityData(s, person)).environmentObject(store)
            }
        }
    }

    private func sessionPostCard(_ s: WorkoutSession) -> some View {
        Button { FX.tap(); detailSession = s } label: {
            PanelCard {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
                    Text(s.name).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft)
                }
                Text(relativeTime(s.date)).font(.caption).foregroundColor(Brand.soft).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    miniStat(durationText(s.elapsed), "Tiempo")
                    miniStat("\(s.sets)", "Series")
                    miniStat("\(s.exercises)", "Ejerc.")
                    if let avg = s.avgHeartRate { miniStat("\(avg)", "ppm") }
                }
            }
        }.buttonStyle(.plain)
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func durationText(_ s: Int) -> String {
        let m = s / 60
        if m >= 60 { return "\(m / 60)h \(m % 60)m" }
        return "\(max(1, m)) min"
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Avatar(emoji: person.avatar, size: 84)
                Text(person.flag).font(.system(size: 16)).frame(width: 24, height: 24)
                    .background(Circle().fill(.white)).overlay(Circle().stroke(Brand.line)).offset(x: 4, y: 4)
            }
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Text(person.name).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                    if person.isPrivate { Image(systemName: "lock.fill").font(.system(size: 13)).foregroundColor(Brand.soft) }
                }
                Text("@\(person.handle)").font(.subheadline).foregroundColor(Brand.muted)
            }
            followButton
        }
    }

    @ViewBuilder
    private var followButton: some View {
        let rel = store.relationship(person.id)
        let label = rel == .friends ? "Siguiendo" : (rel == .outgoing ? "Pendiente" : "Seguir")
        Button { FX.tap(); store.followOrRequest(person.id) } label: {
            HStack(spacing: 6) {
                if rel == .friends { Image(systemName: "checkmark") }
                else if rel == .outgoing { Image(systemName: "clock") }
                Text(label).font(.system(size: 15, weight: .heavy))
            }
            .foregroundColor(rel == .none ? Color(hex: "10150a") : Brand.ink)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(rel == .none ? Brand.green : Brand.chip)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private func statTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
        }.frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Brand.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
    }

    private func friendSessions(_ history: [HistoryEntry]) -> [WorkoutSession] {
        let groups = Dictionary(grouping: history) { $0.sessionId ?? $0.id }
        return groups.map { (sid, entries) -> WorkoutSession in
            let date = entries.map { $0.completedAt }.max() ?? Date()
            let sets = entries.reduce(0) { $0 + $1.sets }
            var seed: UInt64 = 0
            for ch in sid.unicodeScalars { seed = seed &* 31 &+ UInt64(ch.value) }
            let avgHR = 118 + Int(seed % 42)
            let maxHR = avgHR + 12 + Int((seed >> 5) % 22)
            let items = entries.map { e -> SessionExercise in
                let logs = (0..<max(1, e.sets)).map { i in
                    SetLog(reps: e.reps, weight: max(0, e.weight + Double(i) * 2.5 - Double(max(0, e.sets - 1)) * 1.25))
                }
                return SessionExercise(name: e.exerciseName, sets: e.sets, reps: e.reps, weight: e.weight, logs: logs)
            }
            return WorkoutSession(id: sid, name: Self.sessionTitle(entries), note: "", date: date,
                                  elapsed: entries.count * 240 + sets * 40, exercises: entries.count, sets: sets,
                                  volume: entries.reduce(0) { $0 + $1.volume }, xp: 0, photoData: nil,
                                  visibility: .all, items: items, avgHeartRate: avgHR, maxHeartRate: maxHR)
        }.sorted { $0.date > $1.date }
    }

    private static func sessionTitle(_ entries: [HistoryEntry]) -> String {
        var counts: [String: Int] = [:]
        for e in entries { counts[GymScoreEngine.pattern(for: e.exerciseName).group, default: 0] += 1 }
        let top = counts.max { $0.value < $1.value }?.key ?? "accesorio"
        let names = ["pierna": "Pierna", "bisagra": "Cadena posterior", "empuje": "Empuje",
                     "tiron": "Tirón", "condicion": "Cardio & core", "accesorio": "Full body"]
        return names[top] ?? "Entreno"
    }
}

// MARK: - Account setup

struct AccountSetupView: View {
    @EnvironmentObject var store: AppStore
    var allowCancel: Bool
    var onCancel: () -> Void
    @State private var name = ""
    @State private var handle = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @ObservedObject private var health = HealthManager.shared

    private var normalized: String { normalizeHandle(handle) }
    private var taken: [String] { store.people.map { $0.handle } }
    private var handleError: String? {
        if normalized.count < 3 { return "Mínimo 3 caracteres" }
        if taken.contains(normalized) { return "Ese usuario ya existe" }
        return nil
    }
    private var canSubmit: Bool { name.trimmingCharacters(in: .whitespaces).count >= 2 && handleError == nil }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FORGE LOOP").font(.caption2).fontWeight(.heavy).foregroundColor(Color(hex: "4b6211"))
                    Text(store.account == nil ? "Crea tu cuenta" : "Editar cuenta").font(.system(size: 26, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("Elige tu nombre y un @usuario único para que tus amigos te encuentren.").font(.footnote).foregroundColor(Brand.muted)
                }
                HStack {
                    Spacer()
                    PhotoPickerLabel(item: $pickerItem, onPicked: { photoData = $0 }) {
                        ZStack(alignment: .bottomTrailing) {
                            if let d = photoData, let ui = UIImage(data: d) {
                                Image(uiImage: ui).resizable().scaledToFill().frame(width: 84, height: 84).clipShape(Circle())
                            } else {
                                Avatar(emoji: "📷", size: 84)
                            }
                            Image(systemName: "camera.fill").font(.system(size: 12, weight: .bold))
                                .foregroundColor(Brand.ink).padding(7).background(Brand.green).clipShape(Circle())
                        }
                    }
                    Spacer()
                }
                field("Nombre", text: $name, placeholder: "Tu nombre")
                VStack(alignment: .leading, spacing: 5) {
                    Text("USUARIO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    HStack(spacing: 2) {
                        Text("@").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.soft)
                        TextField("tu_usuario", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12).frame(height: 46).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
                    if !normalized.isEmpty, let err = handleError {
                        Text(err).font(.caption).foregroundColor(Color(hex: "c14b46"))
                    } else if !normalized.isEmpty {
                        Text("@\(normalized) disponible").font(.caption).foregroundColor(Color(hex: "4b8a1f"))
                    }
                }
                Button {
                    let isNew = store.account == nil
                    var acc = store.account ?? Account(name: "", handle: "")
                    acc.name = name.trimmingCharacters(in: .whitespaces)
                    acc.handle = normalized
                    if let photoData { acc.photoData = photoData }
                    FX.success(sound: true)
                    store.saveAccount(acc)
                    if isNew && health.isAvailable && !health.connected { Task { await health.connect() } }
                    onCancel()
                } label: { Text(store.account == nil ? "Empezar" : "Guardar") }
                    .buttonStyle(PrimaryButtonStyle(enabled: canSubmit)).disabled(!canSubmit)
                if allowCancel { Button("Cancelar") { onCancel() }.frame(maxWidth: .infinity) }
            }
            .padding(20).background(Brand.bg).clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .padding(22)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
        .onAppear {
            name = store.account?.name ?? ""
            handle = store.account?.handle ?? ""
            photoData = store.account?.photoData
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            TextField(placeholder, text: text)
                .padding(.horizontal, 12).frame(height: 46).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
        }
    }
}
