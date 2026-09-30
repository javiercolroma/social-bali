import SwiftUI

struct PartnerView: View {
    @EnvironmentObject var store: AppStore
    var onOpenChat: (String) -> Void
    @State private var showCreator = false
    @State private var pendingDelete: TrainingPlan?
    @State private var profileTarget: IdString?
    @State private var showMe = false
    @State private var maxKm: Double = 100

    private var visiblePlans: [TrainingPlan] {
        if BackendConfig.isConfigured {
            // Distancia REAL aproximada (celdas de ~5 km). Los planes sin celda —o si yo
            // no comparto ubicación— no se pueden medir: se muestran siempre, al final.
            return store.trainingPlans
                .filter { realKm($0).map { $0 <= maxKm } ?? true }
                .sorted { (realKm($0) ?? .greatestFiniteMagnitude) < (realKm($1) ?? .greatestFiniteMagnitude) }
        }
        return store.trainingPlans
            .filter { planKm($0) <= maxKm }
            .sorted { planKm($0) < planKm($1) }   // los más cercanos primero
    }

    /// Distancia aproximada entre mi celda y la del plan (haversine); nil si falta alguna.
    private func realKm(_ plan: TrainingPlan) -> Double? {
        guard let me = store.myCell, let la = plan.cellLat, let lo = plan.cellLon else { return nil }
        let r = 6371.0, d2r = Double.pi / 180
        let dLat = (la - me.0) * d2r, dLon = (lo - me.1) * d2r
        let a = sin(dLat/2) * sin(dLat/2) + cos(me.0 * d2r) * cos(la * d2r) * sin(dLon/2) * sin(dLon/2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Primera tarjeta de otra persona (para anclar el tutorial de Aceptar/Descartar).
    private var firstOtherPlanId: String? { visiblePlans.first { !store.isMyPlan($0) }?.id }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PanelCard {
                    Button { FX.tap(); showCreator = true } label: {
                        Label("Find a partner", systemImage: "person.2.fill")
                    }.buttonStyle(PrimaryButtonStyle())
                    .tourAnchor("partner.create")

                    VStack(spacing: 8) {
                        HStack {
                            Label("Near me", systemImage: "location.fill").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.muted)
                            Spacer()
                            Text(maxKm >= 99.5 ? "No limit" : "Up to \(Int(maxKm.rounded())) km").font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                        }
                        DistanceSlider(value: $maxKm, range: 1...100)   // mín 1 km, pulgar circular pequeño, continuo
                    }
                    .padding(.top, 4)
                    .tourAnchor("partner.distance")
                }

                if visiblePlans.isEmpty {
                    Text(BackendConfig.isConfigured
                         ? "No plans posted yet. Post yours and find a partner!"
                         : "No partners within \(Int(maxKm.rounded())) km. Widen the distance or post your plan.")
                        .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.top, 30)
                } else {
                    ForEach(visiblePlans) { plan in planCard(plan) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .animation(.easeInOut(duration: 0.2), value: visiblePlans.count)   // aparición/desaparición suave de planes
        }
        .background(Brand.bg)
        .task { store.loadTrainingPlans() }
        .sheet(isPresented: $showCreator) { CreatePlanView().environmentObject(store) }
        .sheet(item: $profileTarget) { item in
            if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
        }
        .sheet(isPresented: $showMe) { MeProfileView().environmentObject(store) }
        .alert("Delete your plan?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), presenting: pendingDelete) { plan in
            Button("Delete", role: .destructive) { FX.warning(); store.deletePlan(plan.id); pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { plan in
            Text("You'll stop looking for a partner for “\(plan.title)”. This can't be undone.")
        }
    }

    /// Distancia aproximada (determinista) a un plan; tus planes están "a 0 km".
    private func planKm(_ plan: TrainingPlan) -> Double {
        if plan.ownerId == "me" { return 0 }
        var s: UInt64 = 7
        for ch in plan.id.unicodeScalars { s = s &* 131 &+ UInt64(ch.value) }
        return Double(s % 96) + 1
    }

    private func planCard(_ plan: TrainingPlan) -> some View {
        let isMine = store.isMyPlan(plan)
        let owner = store.person(plan.ownerId)
        let real = BackendConfig.isConfigured
        return PanelCard {
            // Quién propone (toca para ver el perfil)
            Button {
                FX.tap()
                if isMine { showMe = true } else { profileTarget = IdString(id: plan.ownerId) }
            } label: {
                HStack(spacing: 8) {
                    if real && !isMine {
                        ScoredAvatar(emoji: "🙂", avatarURL: plan.authorAvatarURL, score: store.personScore(plan.ownerId), size: 28)
                    } else {
                        Avatar(emoji: isMine ? "🙂" : (owner?.avatar ?? "👤"), size: 28)
                    }
                    Text(isMine ? "Your plan" : (plan.authorName ?? owner?.name ?? "Partner"))
                        .font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                    Spacer()
                    if !isMine {
                        if real, let km = realKm(plan) {
                            Text("~\(max(1, Int(km.rounded()))) km away").font(.system(size: 12, weight: .heavy)).foregroundColor(Brand.soft)
                        } else if !real {
                            Text("\(Int(planKm(plan))) km away").font(.system(size: 12, weight: .heavy)).foregroundColor(Brand.soft)
                        }
                    }
                    if plan.score > 0 { ScorePill(score: plan.score) }
                }
            }.buttonStyle(.plain)

            // Foco del entreno
            Text(plan.title).font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)

            // Descripción (con peso) — la parte que de verdad cuenta
            if let note = plan.note, !note.isEmpty {
                Text(note).font(.system(size: 15, weight: .semibold)).foregroundColor(Color(hex: "2c3127"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Meta compacta en una sola línea
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.system(size: 11, weight: .bold))
                Text(plan.when)
                Text("·")
                Image(systemName: "mappin.and.ellipse").font(.system(size: 11, weight: .bold))
                Text(plan.place).lineLimit(1)
            }
            .font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.muted)

            if isMine {
                HStack {
                    Text("Waiting for a partner…").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.muted)
                    Spacer()
                    Button(role: .destructive) { pendingDelete = plan } label: { Label("Delete", systemImage: "trash") }
                        .font(.system(size: 13, weight: .heavy))
                }
            } else {
                HStack(spacing: 10) {
                    Button {
                        FX.success(sound: true)
                        store.acceptTrainingPlan(plan.ownerId, "I've accepted your workout. When suits you to meet?")
                        onOpenChat(plan.ownerId)
                    } label: { Text("Accept workout").font(.system(size: 14, weight: .heavy)).frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle())
                        .tourAnchor("partner.accept", if: plan.id == firstOtherPlanId)
                    Button { FX.warning(); store.deletePlan(plan.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(width: 50, height: 50).background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .tourAnchor("partner.discard", if: plan.id == firstOtherPlanId)
                }
            }
        }
    }
}

/// Slider de distancia con pista fina y pulgar circular pequeño; deslizamiento continuo.
private struct DistanceSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    private let thumb: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - thumb)
            let frac = min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
            let x = CGFloat(frac) * usable
            ZStack(alignment: .leading) {
                Capsule().fill(Brand.chip).frame(height: 4)
                Capsule().fill(Brand.green).frame(width: x + thumb / 2, height: 4)
                Circle().fill(.white)
                    .frame(width: thumb, height: thumb)
                    .overlay(Circle().stroke(Brand.green, lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                    .offset(x: x)
            }
            .frame(height: thumb)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let px = min(max(0, g.location.x - thumb / 2), usable)
                    value = range.lowerBound + Double(px / usable) * (range.upperBound - range.lowerBound)
                }
            )
        }
        .frame(height: thumb)
    }
}

struct CreatePlanView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draftWhen = "Tomorrow"
    @State private var draftWhere = "My gym"
    @State private var draftWorkout = "Chest"
    @State private var draftSpots = "1 person"
    @State private var draftNote = ""

    private let whenOptions = ["Today", "Tomorrow", "This week", "Flexible"]
    private let whereOptions = ["My gym", "Near me", "Park / calisthenics", "Flexible"]
    private let workouts = ["Chest", "Back", "Legs", "Push", "Pull", "Full body", "Cardio", "Flexible"]
    private let spotsOptions = ["1 person", "2 people", "Small group", "Flexible"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            Circle().fill(Brand.greenSoft).frame(width: 52, height: 52)
                            Image(systemName: "person.2.fill").font(.system(size: 22, weight: .bold)).foregroundColor(Color(hex: "10150a"))
                        }
                        Text("Find someone to train with").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                        Text("Post your plan and get partners at your level near you.")
                            .font(.footnote).foregroundColor(Brand.muted)
                    }

                    PanelCard {
                        choice("When", "calendar", options: whenOptions, selection: $draftWhen)
                        Divider().background(Brand.line)
                        choice("Where", "mappin.and.ellipse", options: whereOptions, selection: $draftWhere)
                        Divider().background(Brand.line)
                        choice("What", "dumbbell.fill", options: workouts, selection: $draftWorkout)
                        Divider().background(Brand.line)
                        choice("Spots", "person.3.fill", options: spotsOptions, selection: $draftSpots)
                    }

                    PanelCard {
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft").font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "6ea300"))
                            Text("DESCRIPTION (OPTIONAL)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        }
                        TextField("Tell them what you're after, your level, schedule…", text: $draftNote, axis: .vertical)
                            .font(.system(size: 15)).lineLimit(2...5)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        FX.success()
                        let note = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.addPlan(title: planTitle, when: planWhen, place: planPlace, spots: planSpots, score: store.gymScore.total, note: note.isEmpty ? nil : note)
                        dismiss()
                    } label: { Label("Post and search", systemImage: "magnifyingglass") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Find a partner").navigationBarTitleDisplayMode(.inline)
        }
    }

    private func choice(_ label: String, _ icon: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "6ea300"))
                Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            }
            FlowChips(options: options, selection: selection)
        }
    }

    private var planTitle: String {
        switch draftWorkout {
        case "Chest": return "Chest + triceps"
        case "Back": return "Back + biceps"
        case "Flexible": return "Open workout"
        default: return draftWorkout
        }
    }

    private var planWhen: String { draftWhen == "Flexible" ? "Any day" : draftWhen }
    private var planSpots: String { draftSpots == "Flexible" ? "Flexible spots" : draftSpots }

    private var planPlace: String {
        switch draftWhere {
        case "My gym": return store.profile.gym.isEmpty ? "My gym" : store.profile.gym
        case "Park / calisthenics": return "Nearby park"
        case "Flexible": return "Wherever suits you"
        default: return "Nearby area"
        }
    }
}

struct FlowChips: View {
    let options: [String]
    @Binding var selection: String
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(options, id: \.self) { opt in
                Button { selection = opt } label: {
                    Text(opt).font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 10).frame(height: 32).frame(maxWidth: .infinity)
                        .background(selection == opt ? Brand.greenSoft : Brand.chip)
                        .foregroundColor(Brand.ink).clipShape(Capsule())
                }
            }
        }
    }
}
