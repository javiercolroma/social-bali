import SwiftUI

struct PartnerView: View {
    @EnvironmentObject var store: AppStore
    var onOpenChat: (String) -> Void

    @State private var showCreator = false
    @State private var draftWorkout = "Pecho"
    @State private var draftSpots = "1 persona"

    private let workouts = ["Pecho", "Espalda", "Pierna", "Push", "Pull", "Full body", "Cardio"]
    private let spotsOptions = ["1 persona", "2 personas", "Grupo pequeño", "Me adapto"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PanelCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PLANES DE ENTRENO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                            Text("\(store.trainingPlans.count) activos").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.ink)
                        }
                        Spacer()
                        Button { withAnimation { showCreator.toggle() } } label: {
                            Label(showCreator ? "Cerrar" : "Buscar compañero", systemImage: showCreator ? "xmark" : "person.2.fill")
                                .font(.system(size: 12, weight: .heavy))
                                .padding(.horizontal, 10).frame(height: 34)
                                .background(Brand.greenSoft).foregroundColor(Brand.ink).clipShape(Capsule())
                        }
                    }
                    if showCreator { creator }
                }

                if !showCreator {
                    ForEach(store.trainingPlans) { plan in planCard(plan) }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
    }

    private var creator: some View {
        VStack(alignment: .leading, spacing: 10) {
            choice("Qué", options: workouts, selection: $draftWorkout)
            choice("Plazas", options: spotsOptions, selection: $draftSpots)
            Button {
                let title = draftWorkout == "Pecho" ? "Pecho + tríceps" : draftWorkout
                store.addPlan(title: title, place: store.profile.gym, spots: draftSpots, score: store.gymScore.total)
                showCreator = false
            } label: { Label("Crear plan", systemImage: "plus") }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 4)
    }

    private func choice(_ label: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            FlowChips(options: options, selection: selection)
        }
    }

    private func planCard(_ plan: TrainingPlan) -> some View {
        let isMine = plan.ownerId == "me"
        let owner = store.person(plan.ownerId)
        return PanelCard {
            HStack {
                Text(plan.title).font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                Spacer()
                Text(plan.when).font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.muted)
            }
            HStack(spacing: 7) {
                Avatar(emoji: isMine ? "🙂" : (owner?.avatar ?? "👤"), size: 24)
                Text(isMine ? "Tu plan · \(store.account?.name ?? "Tú")" : "Propuesto por \(owner?.name ?? "Compañero")")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "3f4837"))
            }
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill").foregroundColor(Color(hex: "6ea300"))
                Text(plan.place).font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "3f4837"))
            }
            HStack(spacing: 6) { Tag(text: "Score \(plan.score)", highlight: true); Tag(text: plan.spots) }
            if isMine {
                HStack {
                    Text("Esperando compañero…").font(.system(size: 13, weight: .bold)).foregroundColor(Brand.muted)
                    Spacer()
                    Button(role: .destructive) { store.deletePlan(plan.id) } label: { Label("Eliminar", systemImage: "trash") }
                        .font(.system(size: 13, weight: .heavy))
                }
            } else {
                HStack(spacing: 10) {
                    Button {
                        store.acceptTrainingPlan(plan.ownerId, "He aceptado tu entrenamiento. ¿Cuándo te viene bien quedar?")
                        onOpenChat(plan.ownerId)
                    } label: { Text("Aceptar entrenamiento").font(.system(size: 14, weight: .heavy)).frame(maxWidth: .infinity) }
                        .buttonStyle(PrimaryButtonStyle())
                    Button { store.deletePlan(plan.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(width: 50, height: 50).background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
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
                        .padding(.horizontal, 10).frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .background(selection == opt ? Brand.greenSoft : Brand.chip)
                        .foregroundColor(Brand.ink).clipShape(Capsule())
                }
            }
        }
    }
}
