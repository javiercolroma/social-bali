import SwiftUI
import PhotosUI

private enum SetEvent { case done, skip, go }

struct TrainView: View {
    @EnvironmentObject var store: AppStore
    var onGoToPlan: () -> Void = {}
    @State private var sessionStart: Date?
    @State private var showSummary = false
    @State private var previewWorkout: WorkoutTemplate?
    @State private var sessionName = ""
    @State private var sessionNote = ""
    @State private var sessionPhoto: Data?
    @State private var sessionPickerItem: PhotosPickerItem?
    @State private var visibility: WorkoutVisibility = .all
    @State private var restActive = false
    @State private var restElapsed = 0
    @State private var restTotal = 0
    @State private var finalElapsed = 0   // tiempo congelado al terminar (el resumen no debe seguir corriendo)
    @AppStorage("fxSound") private var soundOn = true
    @AppStorage("fxHaptics") private var hapticsOn = true
    @ObservedObject private var health = HealthManager.shared
    @ObservedObject private var remote = WorkoutRemote.shared

    // Detalles de sesión (en memoria, no se persiste)
    @State private var lineSeed = 0              // rota la microcopia del coach
    @State private var lastEvent: SetEvent = .go
    @State private var hitMilestones: Set<Int> = []
    @State private var milestonePop: CGFloat = 1 // pop del tick del 50%
    @State private var burst = 0                  // dispara el "fire" del botón Hecho
    @State private var ringScale: CGFloat = 1.4   // anillo de onda del botón Hecho
    @State private var ringOpacity: Double = 0
    @State private var glow: CGFloat = 12          // radio del resplandor del botón Hecho
    @State private var pulse: CGFloat = 1          // sobreimpulso de escala del botón Hecho

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    // TODO: pruebas — descanso fijo a 10s. Volver a `ex.rest` para producción.
    private let testRestSeconds = 10

    private var totalSets: Int { store.exercises.reduce(0) { $0 + $1.sets } }
    private var closedSets: Int { store.exercises.reduce(0) { $0 + $1.completedSets + $1.skippedSets } }
    private var completedSets: Int { store.exercises.reduce(0) { $0 + $1.completedSets } }
    private var skippedSets: Int { store.exercises.reduce(0) { $0 + $1.skippedSets } }
    private var exercisesDone: Int { store.exercises.filter { $0.completedSets > 0 }.count }
    private var elapsedSeconds: Int { sessionStart.map { max(0, Int(-$0.timeIntervalSinceNow)) } ?? 0 }
    private var finished: Bool { store.activeExercise == nil && !store.exercises.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if store.exercises.isEmpty {
                    emptyState
                } else if showSummary || finished {
                    summary
                } else if let ex = store.activeExercise {
                    sessionHeader
                    restBanner
                    activeCard(ex)
                        .id(ex.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                    finishButton
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: store.activeExercise?.id)
        }
        .background(Brand.bg)
        .sheet(item: $previewWorkout) { WorkoutPreview(workoutId: $0.id).environmentObject(store) }
        .onAppear { if !store.exercises.isEmpty && sessionStart == nil { sessionStart = Date(); health.startSession(); startLive() } }
        // Reaccionar a la IDENTIDAD del entreno cargado: así cargar un entreno nuevo
        // (incluso encima de uno terminado-sin-guardar) reinicia tiempo + captura de FC.
        .onChange(of: store.exercises.first?.id) { id in
            if id == nil { resetLocal() }
            else {
                sessionStart = Date(); restActive = false; restElapsed = 0; showSummary = false
                lineSeed = 0; lastEvent = .go; hitMilestones = []
                health.startSession()
                LiveActivityManager.shared.end(); startLive()
            }
        }
        // Si conectas Salud a mitad de sesión (p. ej. desde Perfil), empieza a captar ya.
        .onChange(of: health.connected) { isOn in
            if isOn && !store.exercises.isEmpty && !showSummary && !finished { health.startSession() }
        }
        .onChange(of: health.liveBPM) { _ in syncLive() }
        // Comandos desde el widget de la pantalla de bloqueo / Isla Dinámica.
        .onReceive(remote.$pending.compactMap { $0 }) { item in apply(item.command) }
        .onReceive(ticker) { _ in
            if restActive && restElapsed < restTotal {
                restElapsed += 1
                if restElapsed >= restTotal {
                    lastEvent = .go; lineSeed += 1   // el coach pasa a "¡Vamos!"
                    fxRest(); syncLive()
                }
            }
        }
    }

    // MARK: - Session

    private var sessionHeader: some View {
        PanelCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workoutName.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    Text("\(closedSets) / \(totalSets) series").font(.system(size: 18, weight: .heavy))
                        .foregroundColor(Brand.ink).contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if let start = sessionStart {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            HStack(spacing: 5) {
                                Image(systemName: "clock.fill").font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
                                Text(timeString(max(0, Int(-start.timeIntervalSinceNow))))
                                    .font(.system(size: 21, weight: .heavy)).monospacedDigit().foregroundColor(Brand.ink)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Brand.surface).clipShape(Capsule())
                        }
                    }
                    heartChip
                }
            }
            GeometryReader { geo in
                let halfway = closedSets * 2 >= totalSets
                ZStack(alignment: .leading) {
                    Capsule().fill(Brand.chip)
                    Capsule().fill(Brand.green)
                        .frame(width: max(6, geo.size.width * CGFloat(closedSets) / CGFloat(max(1, totalSets))))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: closedSets)
                    Circle()
                        .fill(halfway ? Brand.gold : Brand.muted.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(halfway ? milestonePop : 1)
                        .position(x: geo.size.width * 0.5, y: 5)
                }
            }.frame(height: 10)
        }
    }

    @ViewBuilder
    private var heartChip: some View {
        if health.isAvailable {
            if health.connected {
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill").font(.system(size: 12))
                        .foregroundColor(Brand.red)
                    Text(health.liveBPM.map { "\($0)" } ?? "—").font(.system(size: 15, weight: .heavy)).monospacedDigit().foregroundColor(Brand.ink)
                    Text("ppm").font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Brand.surface).clipShape(Capsule())
            } else {
                Button { connectHealth() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill").font(.system(size: 11))
                        Text("Conectar Salud").font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundColor(Color(hex: "a73232"))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Brand.redSoft).clipShape(Capsule())
                }
            }
        }
    }

    private func connectHealth() {
        FX.tap()
        Task { if await health.connect() { health.startSession() } }
    }

    /// Descanso en curso (cuenta atrás activa). Si no, se muestra "¡Haz tu serie!".
    private var resting: Bool { restActive && restElapsed < restTotal }
    private var restRemaining: Int { max(0, restTotal - restElapsed) }

    private var restBanner: some View {
        PanelCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Brand.chip, lineWidth: 7)
                    Circle().trim(from: 0, to: resting ? CGFloat(restRemaining) / CGFloat(max(1, restTotal)) : 1)
                        .stroke(Brand.green, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: restElapsed)
                    if resting {
                        Text(timeString(restRemaining)).font(.system(size: 17, weight: .heavy)).monospacedDigit().foregroundColor(Brand.ink)
                    } else {
                        Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 26)).foregroundColor(Color(hex: "4b6211"))
                    }
                }.frame(width: 70, height: 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coachTitle)
                        .font(.system(size: 17, weight: .heavy)).foregroundColor(resting ? Brand.ink : Color(hex: "4b6211"))
                    Text(coachSub).font(.caption).foregroundColor(Brand.muted).lineLimit(1)
                }
                .id(lineSeed)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeOut(duration: 0.25), value: lineSeed)
                Spacer()
                if resting {
                    Button { restTotal += 15; Haptics.soft(); syncLive() } label: {
                        Text("+15s").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                            .padding(.horizontal, 14).frame(height: 38).background(Brand.chip).clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func activeCard(_ ex: Exercise) -> some View {
        let current = min(ex.sets, ex.completedSets + ex.skippedSets + 1)
        return PanelCard {
            HStack {
                Text(ex.day.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                Spacer()
                Text("SERIE \(current) DE \(ex.sets)").font(.caption2).fontWeight(.heavy).foregroundColor(Color(hex: "4b6211"))
            }
            Text(ex.name).font(.system(size: 28, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(2)
            HStack(spacing: 7) {
                ForEach(0..<ex.sets, id: \.self) { i in
                    Circle().fill(dotColor(ex, i))
                        .frame(width: 13, height: 13)
                        .scaleEffect(i == ex.completedSets + ex.skippedSets - 1 ? 1.25 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: ex.completedSets + ex.skippedSets)
                }
            }
            HStack(spacing: 12) {
                editStat("repeat", "\(ex.reps)", "reps",
                         minus: { store.adjustReps(ex.id, -1); Haptics.soft() },
                         plus: { store.adjustReps(ex.id, 1); Haptics.soft() })
                editStat("dumbbell.fill", weightText(ex.weight), "kg",
                         minus: { store.adjustWeight(ex.id, -2.5); Haptics.soft() },
                         plus: { store.adjustWeight(ex.id, 2.5); Haptics.soft() })
            }.padding(.vertical, 6)
            HStack(spacing: 10) {
                Button { register(ex, done: false) } label: {
                    Label("Saltar", systemImage: "xmark").font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color(hex: "a73232")).frame(maxWidth: .infinity).frame(minHeight: 56)
                        .background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(PressableButtonStyle())
                Button { register(ex, done: true) } label: {
                    Label("Hecho", systemImage: "checkmark").font(.system(size: 17, weight: .heavy))
                        .foregroundColor(Color(hex: "10150a")).frame(maxWidth: .infinity).frame(minHeight: 56)
                        .background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Brand.green.opacity(0.5), radius: glow, y: 6)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Brand.green, lineWidth: 3)
                                .scaleEffect(ringScale)
                                .opacity(ringOpacity)
                                .allowsHitTesting(false)
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .scaleEffect(pulse)
            }
        }
    }

    private var finishButton: some View {
        Button { finalElapsed = elapsedSeconds; LiveActivityManager.shared.end(); withAnimation { showSummary = true } } label: {
            Label("Finalizar entrenamiento", systemImage: "flag.checkered")
                .font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(maxWidth: .infinity).frame(minHeight: 48)
                .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func register(_ ex: Exercise, done: Bool) {
        if sessionStart == nil { sessionStart = Date() }
        let willClose = (ex.completedSets + ex.skippedSets + 1) >= ex.sets
        if done { restActive = true; restTotal = testRestSeconds; restElapsed = 0 } else { restActive = false }

        lineSeed += 1
        lastEvent = done ? .done : .skip

        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { store.registerSet(ex.id, done: done) }
        if store.activeExercise == nil { finalElapsed = elapsedSeconds; LiveActivityManager.shared.end() }   // último set

        // Hito del 50% (una sola vez por sesión).
        let pct = Double(closedSets) / Double(max(1, totalSets))
        if pct >= 0.5 && pct < 1.0 && hitMilestones.insert(50).inserted {
            if soundOn { Synth.shared.milestone() }
            if hapticsOn { Haptics.success() }
            milestonePop = 1.7
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { milestonePop = 1 }
        }

        if willClose && store.activeExercise != nil {
            fxExercise()   // moved to the next exercise: special sound
        } else if done {
            fxDone()
        } else {
            fxSkip()
        }
        if done { triggerBurst() }
        syncLive()
    }

    /// "Fire" del botón Hecho: onda + resplandor + sobreimpulso (sin mover el layout).
    private func triggerBurst() {
        burst += 1
        ringScale = 0.6; ringOpacity = 0.7; glow = 24; pulse = 1.07
        withAnimation(.easeOut(duration: 0.45)) { ringScale = 1.5; ringOpacity = 0; glow = 12 }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { pulse = 1 }
    }

    // MARK: - Coach (microcopia reactiva del descanso)

    private let restLines = ["Recupera para la próxima serie", "Respira. Vuelves más fuerte.",
                             "Suelta tensión y prepárate.", "Aprovecha, la siguiente es tuya."]
    private let skipLines = ["Sin drama. La próxima es tuya.", "Tranqui, sigue el plan.",
                             "Apunta a por la siguiente."]
    private let goLines = ["Cuando estés listo, a por ello", "Técnica limpia, fuerza total.",
                           "Una serie más. Tú puedes.", "Concéntrate y empuja."]

    private var coachTitle: String {
        if !resting { return lastEvent == .go ? "¡Vamos!" : "¡Haz tu serie!" }
        return "Descanso"
    }
    private var coachSub: String {
        if !resting { return goLines[lineSeed % goLines.count] }
        if lastEvent == .skip { return skipLines[lineSeed % skipLines.count] }
        return restLines[lineSeed % restLines.count]
    }

    /// Serie actual (1-based) del ejercicio activo, para mostrarla en el widget.
    private func currentSetIndex(_ ex: Exercise) -> Int { min(ex.sets, ex.completedSets + ex.skippedSets + 1) }

    private func startLive() {
        guard let start = sessionStart else { return }
        let ex = store.activeExercise
        LiveActivityManager.shared.start(name: workoutName, startedAt: start,
                                         closedSets: closedSets, totalSets: totalSets,
                                         currentExercise: ex?.name ?? "",
                                         reps: ex?.reps ?? 0, weight: ex?.weight ?? 0,
                                         setIndex: ex.map(currentSetIndex) ?? 0, exerciseSets: ex?.sets ?? 0)
    }

    private func syncLive() {
        guard let start = sessionStart, let ex = store.activeExercise else { return }
        LiveActivityManager.shared.update(name: workoutName, startedAt: start,
                                          closedSets: closedSets, totalSets: totalSets,
                                          currentExercise: ex.name,
                                          reps: ex.reps, weight: ex.weight,
                                          setIndex: currentSetIndex(ex), exerciseSets: ex.sets,
                                          bpm: health.liveBPM, resting: resting,
                                          restStartedAt: resting ? Date().addingTimeInterval(-Double(restElapsed)) : nil,
                                          restEndsAt: resting ? Date().addingTimeInterval(Double(restRemaining)) : nil)
    }

    /// Aplica un comando llegado desde el widget (botones de la Live Activity) usando
    /// la misma lógica que la UI dentro de la app.
    private func apply(_ command: WorkoutCommand) {
        guard let ex = store.activeExercise else { return }
        switch command {
        case .done: register(ex, done: true)
        case .skip: register(ex, done: false)
        // El widget ya se actualizó al instante en el App Intent (LiveActivityManager.bump*);
        // aquí solo sincronizamos el store/UI de la app (sin re-empujar la Live Activity).
        case .repsUp:    store.adjustReps(ex.id, 1);     Haptics.soft()
        case .repsDown:  store.adjustReps(ex.id, -1);    Haptics.soft()
        case .weightUp:   store.adjustWeight(ex.id, 2.5);  Haptics.soft()
        case .weightDown: store.adjustWeight(ex.id, -2.5); Haptics.soft()
        case .restPlus:
            if resting { restTotal += 15; Haptics.soft(); syncLive() }
        case .restSkip:
            if resting { restActive = false; restElapsed = restTotal; Haptics.soft(); syncLive() }
        }
    }

    // MARK: - Summary

    private var summary: some View {
        ZStack(alignment: .top) {
            PanelCard {
                HStack { Spacer(); Text("🏁").font(.system(size: 46)); Spacer() }
                Text("¡Buen trabajo!").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: 10) {
                    summaryStat(timeString(finalElapsed), "Duración", "clock")
                    summaryStat("\(completedSets)", "Series", "checkmark.circle")
                }
                HStack(spacing: 10) {
                    summaryStat(health.sessionAvg.map { "\($0)" } ?? "—", "FC media", "heart.fill")
                    summaryStat(health.sessionMax.map { "\($0)" } ?? "—", "FC máx", "heart.fill")
                }
                if skippedSets > 0 {
                    Text("\(skippedSets) series saltadas · \(exercisesDone) ejercicios").font(.caption).foregroundColor(Brand.soft)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Divider().padding(.vertical, 2)

                summaryLabel("NOMBRE DEL ENTRENO")
                TextField(defaultSessionName, text: $sessionName)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 12).frame(height: 44).background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                summaryLabel("¿QUÉ TAL TE HA IDO?")
                TextField("Cómo te has sentido, sensaciones…", text: $sessionNote, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(2...4)
                    .padding(.horizontal, 12).padding(.vertical, 10).background(Brand.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                summaryLabel("FOTO DEL ENTRENO (OPCIONAL)")
                PhotoPickerLabel(item: $sessionPickerItem, onPicked: { sessionPhoto = $0 }) {
                    if let data = sessionPhoto, let ui = UIImage(data: data) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(height: 120).frame(maxWidth: .infinity).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil.circle.fill").font(.system(size: 24)).foregroundColor(.white).padding(6)
                            }
                    } else {
                        HStack(spacing: 8) { Image(systemName: "camera.fill"); Text("Añadir foto") }
                            .font(.system(size: 15, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                            .background(Brand.greenSoft.opacity(0.22)).clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: "9ec85a"), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                    }
                }

                summaryLabel("¿QUIÉN PUEDE VERLO?")
                HStack(spacing: 8) {
                    ForEach(WorkoutVisibility.allCases, id: \.self) { v in
                        Button { FX.tap(); visibility = v } label: {
                            HStack(spacing: 5) {
                                Image(systemName: v.icon).font(.system(size: 11, weight: .bold))
                                Text(v.label).font(.system(size: 12, weight: .heavy))
                            }
                            .frame(maxWidth: .infinity).frame(height: 38)
                            .background(visibility == v ? Brand.greenSoft : Brand.chip)
                            .foregroundColor(Brand.ink).clipShape(Capsule())
                        }
                    }
                }

                Button {
                    fxFinish()
                    let hr = health.endSession()
                    store.saveSession(name: sessionName, note: sessionNote, photoData: sessionPhoto, visibility: visibility,
                                      elapsed: finalElapsed, avgHeartRate: hr.avg, maxHeartRate: hr.max)
                    resetLocal()
                } label: { Label("Guardar entrenamiento", systemImage: "checkmark") }
                    .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
                Button(role: .destructive) { store.discardSession(); resetLocal() } label: {
                    Label("Descartar", systemImage: "trash").frame(maxWidth: .infinity)
                }.padding(.top, 2)
            }
            ConfettiView().frame(height: 320).allowsHitTesting(false)
        }
        .onAppear { fxFinish(); if sessionName.isEmpty { sessionName = defaultSessionName }; if finalElapsed == 0 { finalElapsed = elapsedSeconds } }
    }

    private func summaryLabel(_ text: String) -> some View {
        Text(text).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 2)
    }

    private func summaryStat(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(Color(hex: "6ea300"))
            Text(value).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var workoutName: String { store.exercises.first?.day ?? "Entreno" }

    /// Strava-style default with a gym twist: "<grupo> de <franja>" (e.g. "Pierna de tarde").
    private var defaultSessionName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let time = hour < 12 ? "de mañana" : (hour < 21 ? "de tarde" : "de noche")
        var counts: [String: Int] = [:]
        for e in store.exercises { counts[GymScoreEngine.pattern(for: e.name).group, default: 0] += 1 }
        let top = counts.max { $0.value < $1.value }?.key ?? ""
        let labels = ["pierna": "Pierna", "bisagra": "Posterior", "empuje": "Empuje",
                      "tiron": "Tirón", "condicion": "Cardio", "accesorio": "Full body"]
        return "\(labels[top] ?? "Entreno") \(time)"
    }
    private func resetLocal() {
        health.endSession()
        LiveActivityManager.shared.end()
        sessionStart = nil; restActive = false; restElapsed = 0; restTotal = 0; finalElapsed = 0; showSummary = false
        sessionName = ""; sessionNote = ""; sessionPhoto = nil; sessionPickerItem = nil; visibility = .all
        lineSeed = 0; lastEvent = .go; hitMilestones = []
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 40)
            ZStack {
                Circle().fill(Brand.greenSoft).frame(width: 96, height: 96)
                Image(systemName: "dumbbell.fill").font(.system(size: 40, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
            }
            VStack(spacing: 6) {
                Text("¿Qué entrenamos hoy?").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Elige un entreno para empezar tu sesión.")
                    .font(.subheadline).foregroundColor(Brand.muted).multilineTextAlignment(.center)
            }
            Button { onGoToPlan() } label: { Label("Elegir entreno", systemImage: "square.grid.2x2") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - FX

    private func fxDone() { if hapticsOn { Haptics.success() }; if soundOn { Synth.shared.done() } }
    private func fxSkip() { if hapticsOn { Haptics.soft() }; if soundOn { Synth.shared.skip() } }
    private func fxExercise() { if hapticsOn { Haptics.success() }; if soundOn { Synth.shared.exercise() } }
    private func fxRest() { if hapticsOn { Haptics.rigid() }; if soundOn { Synth.shared.rest() } }
    private func fxFinish() { if hapticsOn { Haptics.success() }; if soundOn { Synth.shared.finish() } }

    // MARK: - Helpers

    private func editStat(_ icon: String, _ value: String, _ label: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(Color(hex: "6ea300"))
            HStack(spacing: 12) {
                stepButton("minus", action: minus)
                Text(value).font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                    .frame(minWidth: 44).contentTransition(.numericText())
                stepButton("plus", action: plus)
            }
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                .frame(width: 32, height: 32).background(Color.white).clipShape(Circle())
                .overlay(Circle().stroke(Brand.line))
        }.buttonStyle(PressableButtonStyle())
    }

    private func dotColor(_ ex: Exercise, _ i: Int) -> Color {
        if i < ex.completedSets { return Brand.green }
        if i < ex.completedSets + ex.skippedSets { return Brand.red.opacity(0.6) }
        return Brand.chip
    }

    private func weightText(_ w: Double) -> String { w == w.rounded() ? String(Int(w)) : String(format: "%.1f", w) }
    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}
