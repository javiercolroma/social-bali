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
        store.trainingPlans.filter { planKm($0) <= maxKm }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PanelCard {
                    Button { FX.tap(); showCreator = true } label: {
                        Label("Buscar compañero", systemImage: "person.2.fill")
                    }.buttonStyle(PrimaryButtonStyle())

                    HStack {
                        Label("Cerca de mí", systemImage: "location.fill").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.muted)
                        Spacer()
                        Text(maxKm >= 99.5 ? "Sin límite" : "Hasta \(Int(maxKm.rounded())) km").font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                    }.padding(.top, 4)
                    DistanceSlider(value: $maxKm, range: 1...100)   // mín 1 km, pulgar circular pequeño, continuo
                }

                if visiblePlans.isEmpty {
                    Text("No hay compañeros a menos de \(Int(maxKm.rounded())) km. Amplía la distancia o publica tu plan.")
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
        .sheet(isPresented: $showCreator) { CreatePlanView().environmentObject(store) }
        .sheet(item: $profileTarget) { item in
            if let p = store.person(item.id) { FriendProfileView(person: p).environmentObject(store) }
        }
        .sheet(isPresented: $showMe) { MeProfileView().environmentObject(store) }
        .confirmationDialog("¿Eliminar este plan?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { FX.warning(); if let p = pendingDelete { store.deletePlan(p.id) }; pendingDelete = nil }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
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
        let isMine = plan.ownerId == "me"
        let owner = store.person(plan.ownerId)
        return PanelCard {
            HStack {
                Text(plan.title).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 11, weight: .bold))
                    Text(plan.when).font(.system(size: 13, weight: .heavy))
                }.foregroundColor(Brand.muted)
            }
            Button {
                FX.tap()
                if isMine { showMe = true } else if let o = owner { profileTarget = IdString(id: o.id) }
            } label: {
                HStack(spacing: 7) {
                    Avatar(emoji: isMine ? "🙂" : (owner?.avatar ?? "👤"), size: 24)
                    Text(isMine ? "Tu plan · \(store.account?.name ?? "Tú")" : "Propuesto por \(owner?.name ?? "Compañero")")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "3f4837"))
                }
            }.buttonStyle(.plain)
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill").foregroundColor(Color(hex: "6ea300"))
                Text(plan.place).font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "3f4837"))
                if !isMine { Text("· a \(Int(planKm(plan))) km").font(.system(size: 12, weight: .heavy)).foregroundColor(Brand.soft) }
            }
            if let note = plan.note, !note.isEmpty {
                Text(note).font(.system(size: 13)).foregroundColor(Color(hex: "2c3127")).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) { Tag(text: "Score \(plan.score)", highlight: true); Tag(text: plan.spots) }
            if isMine {
                HStack {
                    Text("Esperando compañero…").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.muted)
                    Spacer()
                    Button(role: .destructive) { pendingDelete = plan } label: { Label("Eliminar", systemImage: "trash") }
                        .font(.system(size: 13, weight: .heavy))
                }
            } else {
                HStack(spacing: 10) {
                    Button {
                        FX.success(sound: true)
                        store.acceptTrainingPlan(plan.ownerId, "He aceptado tu entrenamiento. ¿Cuándo te viene bien quedar?")
                        onOpenChat(plan.ownerId)
                    } label: { Text("Aceptar entrenamiento").font(.system(size: 14, weight: .heavy)).frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button { FX.warning(); store.deletePlan(plan.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(width: 50, height: 50).background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
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
    @State private var draftWhen = "Mañana"
    @State private var draftWhere = "Mi gimnasio"
    @State private var draftWorkout = "Pecho"
    @State private var draftSpots = "1 persona"
    @State private var draftNote = ""

    private let whenOptions = ["Hoy", "Mañana", "Esta semana", "Me adapto"]
    private let whereOptions = ["Mi gimnasio", "Cerca de mí", "Parque / calistenia", "Me adapto"]
    private let workouts = ["Pecho", "Espalda", "Pierna", "Push", "Pull", "Full body", "Cardio", "Me adapto"]
    private let spotsOptions = ["1 persona", "2 personas", "Grupo pequeño", "Me adapto"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            Circle().fill(Brand.greenSoft).frame(width: 52, height: 52)
                            Image(systemName: "person.2.fill").font(.system(size: 22, weight: .bold)).foregroundColor(Color(hex: "10150a"))
                        }
                        Text("Encuentra con quién entrenar").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                        Text("Publica tu plan y recibe compañeros con tu nivel cerca de ti.")
                            .font(.footnote).foregroundColor(Brand.muted)
                    }

                    PanelCard {
                        choice("Cuándo", "calendar", options: whenOptions, selection: $draftWhen)
                        Divider().background(Brand.line)
                        choice("Dónde", "mappin.and.ellipse", options: whereOptions, selection: $draftWhere)
                        Divider().background(Brand.line)
                        choice("Qué", "dumbbell.fill", options: workouts, selection: $draftWorkout)
                        Divider().background(Brand.line)
                        choice("Plazas", "person.3.fill", options: spotsOptions, selection: $draftSpots)
                    }

                    PanelCard {
                        HStack(spacing: 6) {
                            Image(systemName: "text.alignleft").font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "6ea300"))
                            Text("DESCRIPCIÓN (OPCIONAL)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        }
                        TextField("Cuéntales qué buscas, tu nivel, horario…", text: $draftNote, axis: .vertical)
                            .font(.system(size: 15)).lineLimit(2...5)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        FX.success()
                        let note = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.addPlan(title: planTitle, when: planWhen, place: planPlace, spots: planSpots, score: store.gymScore.total, note: note.isEmpty ? nil : note)
                        dismiss()
                    } label: { Label("Publicar y buscar", systemImage: "magnifyingglass") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Buscar compañero").navigationBarTitleDisplayMode(.inline)
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
        case "Pecho": return "Pecho + tríceps"
        case "Espalda": return "Espalda + bíceps"
        case "Me adapto": return "Entreno libre"
        default: return draftWorkout
        }
    }

    private var planWhen: String { draftWhen == "Me adapto" ? "Cualquier día" : draftWhen }
    private var planSpots: String { draftSpots == "Me adapto" ? "Plazas flexibles" : draftSpots }

    private var planPlace: String {
        switch draftWhere {
        case "Mi gimnasio": return store.profile.gym.isEmpty ? "Mi gimnasio" : store.profile.gym
        case "Parque / calistenia": return "Parque cercano"
        case "Me adapto": return "Donde te venga bien"
        default: return "Zona cercana"
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
