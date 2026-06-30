import SwiftUI
import PhotosUI

/// Acompañamiento cálido para usuarios nuevos: Forgey (la mascota) te guía con una
/// pregunta amable por pantalla. Solo para cuentas nuevas (editar usa `AccountSetupView`).
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var health = HealthManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Step: Int, CaseIterable { case welcome, name, handle, goal, level, days, motivation, photo, about, place, health, done }
    private enum Field { case name, handle }

    @State private var step: Step = .welcome
    @State private var goingBack = false
    @FocusState private var focus: Field?

    // Datos (viven aquí para no perderlos al volver atrás)
    @State private var name = ""
    @State private var handle = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoScale: CGFloat = 1
    @State private var photoOffset: CGSize = .zero
    @State private var showFramer = false
    @State private var birthYear = 1997
    @State private var sexSel = "Hombre"
    @State private var aboutDone = false
    @State private var country = "España"
    @State private var city = ""
    @State private var gym = ""

    // Encuesta tipo tarjeta (una pregunta por pantalla, selección única)
    @State private var goalSel: String?
    @State private var levelSel: String?
    @State private var daysSel: String?
    @State private var motivSel: String?
    @State private var shownBubbles: Set<Int> = []   // pasos cuyo bocadillo ya se escribió (no re-typear al volver)
    @State private var bounceTrigger = 0             // anima a Forgey al elegir
    @State private var reactionLine: String?         // chip de reacción de Forgey

    @State private var drawCheck: CGFloat = 0
    @State private var avatarIn = false

    private let sexes = ["Hombre", "Mujer", "Otro", "No especificar"]
    private var years: [Int] {
        let now = Calendar.current.component(.year, from: Date())
        return Array(1930...(now - 13))
    }

    // MARK: - Validación

    private var firstName: String {
        name.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
    }
    private var normalized: String { normalizeHandle(handle) }
    private var taken: [String] { store.people.map { $0.handle } }
    private var handleError: String? {
        if normalized.count < 3 { return "Mínimo 3 caracteres" }
        if taken.contains(normalized) { return "Ese usuario ya existe" }
        return nil
    }
    private var nameOK: Bool { name.trimmingCharacters(in: .whitespaces).count >= 2 }
    private var handleOK: Bool { handleError == nil }
    private var progress: Double { Double(step.rawValue) / Double(Step.allCases.count - 1) }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Brand.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                stepBody
                    .id(step)
                    .transition(slide)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
            }
        }
        .onChange(of: step) { _ in
            reactionLine = nil   // la reacción de Forgey es por pantalla
            if step == .name { focusSoon(.name) }
            else if step == .handle { focusSoon(.handle) }
            else { focus = nil }
            if step == .done { runFinish() }
        }
    }

    private var slide: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
            removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity))
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Brand.greenSoft.opacity(0.5))
                    Capsule().fill(Brand.green).frame(width: max(0, geo.size.width * progress))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progress)
                }
            }.frame(height: 3)
            HStack {
                if step != .welcome && step != .done {
                    Button { back() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink.opacity(0.55))
                            .frame(width: 36, height: 36)
                    }
                }
                Spacer()
            }.frame(height: 36)
        }
        .padding(.horizontal, 16).padding(.top, 8)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .welcome: welcomeStep
        case .name: nameStep
        case .handle: handleStep
        case .goal: surveyStep(OnboardingSurvey.goal, selection: $goalSel)
        case .level: surveyStep(OnboardingSurvey.level, selection: $levelSel)
        case .days: surveyStep(OnboardingSurvey.days, selection: $daysSel)
        case .motivation: surveyStep(OnboardingSurvey.motivation, selection: $motivSel, isLast: true)
        case .photo: photoStep
        case .about: aboutStep
        case .place: placeStep
        case .health: healthStep
        case .done: doneStep
        }
    }

    private var welcomeStep: some View {
        layout {
            Mascot(size: 150, wave: true)
            TypingBubble("¡Hola! Soy Forgey 💪 Vamos a montar tu plan en un momento.",
                         typing: !shownBubbles.contains(Step.welcome.rawValue)) { shownBubbles.insert(Step.welcome.rawValue) }
        } actions: {
            primary("Empezar") { advance() }
        }
    }

    private var nameStep: some View {
        layout {
            Mascot(size: 96)
            Bubble("¿Cómo te llamas?")
            TextField("Tu nombre", text: $name)
                .multilineTextAlignment(.center).font(.system(size: 22, weight: .heavy))
                .foregroundColor(Brand.ink).tint(Brand.ink)
                .focused($focus, equals: .name).submitLabel(.next).onSubmit { if nameOK { advance() } }
                .padding(.horizontal, 14).frame(height: 58).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(focus == .name ? Brand.green : Brand.line, lineWidth: focus == .name ? 1.8 : 1))
        } actions: {
            primary("Continuar", enabled: nameOK) { advance() }
        }
    }

    private var handleStep: some View {
        layout {
            Mascot(size: 96)
            Bubble(firstName.isEmpty ? "Elige tu nombre de usuario" : "Encantado, \(firstName). Elige tu usuario")
            VStack(spacing: 8) {
                HStack(spacing: 2) {
                    Text("@").font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.soft)
                    TextField("usuario", text: $handle).font(.system(size: 22, weight: .heavy)).foregroundColor(Brand.ink).tint(Brand.ink)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focus, equals: .handle).submitLabel(.next).onSubmit { if handleOK { advance() } }
                }
                .padding(.horizontal, 16).frame(height: 58).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(focus == .handle ? Brand.green : Brand.line, lineWidth: focus == .handle ? 1.8 : 1))
                if !normalized.isEmpty, let err = handleError {
                    hint(err, "exclamationmark.circle.fill", Color(hex: "c14b46"))
                } else if !normalized.isEmpty {
                    hint("@\(normalized) está libre", "checkmark.circle.fill", Color(hex: "4b8a1f"))
                }
            }
        } actions: {
            primary("Continuar", enabled: handleOK) { advance() }
        }
    }

    /// Pregunta de encuesta (selección única, estilo conversacional): Forgey escribe
    /// la pregunta, aparecen tarjetas, eliges una (con reacción de Forgey) y continúas.
    private func surveyStep(_ q: SurveyQuestion, selection: Binding<String?>, isLast: Bool = false) -> some View {
        let done = shownBubbles.contains(step.rawValue)
        return layout {
            // Reacción de Forgey: en su PROPIO espacio, encima de la cabeza (no sobre la cara).
            ZStack {
                if let line = reactionLine {
                    ReactionChip(text: line).transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .frame(height: 32)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: reactionLine)
            Mascot(size: 88, bounceTrigger: bounceTrigger)
            TypingBubble(q.prompt, typing: !done) { shownBubbles.insert(step.rawValue) }
            VStack(spacing: 10) {
                ForEach(Array(q.options.enumerated()), id: \.element.label) { idx, opt in
                    SelectCard(emoji: opt.emoji, label: opt.label, selected: selection.wrappedValue == opt.label) {
                        guard selection.wrappedValue != opt.label else { return }
                        FX.selection()
                        selection.wrappedValue = opt.label
                        bounceTrigger += 1
                        withAnimation(.easeOut(duration: 0.2)) { reactionLine = q.reaction(opt.label) }
                    }
                    .opacity(done ? 1 : 0).offset(y: done ? 0 : 10)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(done ? Double(idx) * 0.05 : 0), value: done)
                    .allowsHitTesting(done)
                }
            }
        } actions: {
            primary("Continuar", enabled: selection.wrappedValue != nil) {
                if isLast { FX.success() }
                advance()
            }
        }
    }

    private var photoStep: some View {
        layout {
            TypingBubble(firstName.isEmpty ? "¡Ya te conozco mejor! 🙌 ¿Le ponemos cara?" : "¡Ya te conozco mejor, \(firstName)! 🙌 ¿Le ponemos cara?",
                         typing: !shownBubbles.contains(Step.photo.rawValue)) { shownBubbles.insert(Step.photo.rawValue) }
            // Tocar el círculo: si hay foto, reencuadra; si no, abre el selector.
            Group {
                if let d = photoData, let ui = UIImage(data: d) {
                    Button { showFramer = true } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .scaleEffect(photoScale)
                                .offset(x: photoOffset.width * (150 / 240), y: photoOffset.height * (150 / 240))
                                .frame(width: 150, height: 150).clipShape(Circle())
                            badge("crop")
                        }
                    }.buttonStyle(.plain)
                } else {
                    PhotoPickerLabel(item: $pickerItem, onPicked: { onPhotoPicked($0) }) {
                        ZStack(alignment: .bottomTrailing) {
                            ZStack {
                                Circle().fill(Brand.chip).frame(width: 150, height: 150)
                                Image(systemName: "camera.fill").font(.system(size: 40)).foregroundColor(Brand.soft)
                            }
                            badge("plus")
                        }
                    }
                }
            }
        } actions: {
            if photoData == nil {
                PhotoPickerLabel(item: $pickerItem, onPicked: { onPhotoPicked($0) }) {
                    Text("Elegir foto")
                        .font(.system(size: 16, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Brand.green).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                primary("Usar esta foto") { advance() }
                PhotoPickerLabel(item: $pickerItem, onPicked: { onPhotoPicked($0) }) {
                    Text("Elegir otra").font(.system(size: 14, weight: .bold)).foregroundColor(Brand.soft)
                        .frame(maxWidth: .infinity).frame(height: 36)
                }
            }
            skip()
        }
        .sheet(isPresented: $showFramer) {
            if let d = photoData {
                OnboardingPhotoFramer(data: d, scale: $photoScale, offset: $photoOffset) { showFramer = false }
            }
        }
    }

    private func badge(_ icon: String) -> some View {
        Image(systemName: icon).font(.system(size: 16, weight: .heavy))
            .foregroundColor(Brand.ink).padding(11).background(Brand.green).clipShape(Circle())
            .overlay(Circle().stroke(Brand.bg, lineWidth: 4))
    }

    /// Tras elegir foto: guarda los datos, resetea encuadre y abre el editor para encuadrar.
    private func onPhotoPicked(_ data: Data) {
        photoData = data; photoScale = 1; photoOffset = .zero; Haptics.soft()
        showFramer = true
    }

    private var aboutStep: some View {
        layout {
            Mascot(size: 88)
            TypingBubble("Cuéntame un poco sobre ti",
                         typing: !shownBubbles.contains(Step.about.rawValue)) { shownBubbles.insert(Step.about.rawValue) }
            VStack(spacing: 0) {
                wheelLabel("¿Cuándo naciste?")
                Picker("Año", selection: $birthYear) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }.pickerStyle(.wheel).frame(height: 104).clipped()
                Divider().overlay(Brand.line)
                wheelLabel("¿Cuál es tu sexo?")
                Picker("Género", selection: $sexSel) {
                    ForEach(sexes, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.wheel).frame(height: 104).clipped()
            }
            .frame(maxWidth: .infinity)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
        } actions: {
            primary("Continuar") { aboutDone = true; advance() }
            skip()
        }
    }

    private var placeStep: some View {
        layout {
            Mascot(size: 88)
            TypingBubble("¿Dónde sueles entrenar?",
                         typing: !shownBubbles.contains(Step.place.rawValue)) { shownBubbles.insert(Step.place.rawValue) }
            VStack(spacing: 10) {
                CountryField(label: "", selected: country) { country = $0 }
                CitySearchField(label: "", selected: city, country: country) { city = $0 }
                HStack(spacing: 10) {
                    Image(systemName: "dumbbell.fill").foregroundColor(Brand.soft)
                    TextField("Tu gimnasio (opcional)", text: $gym).font(.system(size: 16, weight: .semibold)).tint(Brand.ink)
                }
                .padding(.horizontal, 14).frame(height: 50).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
            }
        } actions: {
            primary("Continuar") { advance() }
            skip()
        }
    }

    private var healthStep: some View {
        layout {
            Mascot(size: 96, holdsHeart: true)
            TypingBubble(health.isAvailable ? "¿Conectamos con Salud para ver tu pulso en cada serie?"
                                            : "Cuando tengas el iPhone a mano podrás conectar Salud desde tu perfil.",
                         typing: !shownBubbles.contains(Step.health.rawValue)) { shownBubbles.insert(Step.health.rawValue) }
        } actions: {
            if health.isAvailable && !health.connected {
                primary("Conectar con Salud") { Task { _ = await health.connect(); advance() } }
                skip()
            } else {
                primary(health.connected ? "¡Conectado! Seguir" : "Seguir") { advance() }
            }
        }
    }

    private var doneStep: some View {
        layout {
            ZStack {
                Circle().stroke(Brand.greenSoft, lineWidth: 7).frame(width: 150, height: 150)
                Circle().trim(from: 0, to: drawCheck).stroke(Brand.green, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 150, height: 150)
                MeAvatar(account: previewAccount, size: 116)
                    .scaleEffect(avatarIn ? 1 : 0.4).opacity(avatarIn ? 1 : 0)
            }
            Bubble(firstName.isEmpty ? "¡Todo listo! A darlo todo 🔥" : "¡Listo, \(firstName)! A darlo todo 🔥")
        } actions: {
            primary("Entrar a Forge Loop") { commit() }
        }
    }

    private var previewAccount: Account {
        var a = Account(name: name.trimmingCharacters(in: .whitespaces), handle: normalized, photoData: photoData)
        a.photoScale = Double(photoScale)
        a.photoOffsetX = Double(photoOffset.width)
        a.photoOffsetY = Double(photoOffset.height)
        return a
    }

    // MARK: - Layout helper (centrado, con acciones abajo)

    @ViewBuilder
    private func layout<C: View, A: View>(@ViewBuilder content: () -> C, @ViewBuilder actions: () -> A) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            VStack(spacing: 18) { content() }
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
            VStack(spacing: 4) { actions() }
        }
        .padding(.bottom, 14)
    }

    private func wheelLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 2)
    }
    private func hint(_ t: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 5) { Image(systemName: icon); Text(t) }
            .font(.system(size: 14, weight: .heavy)).foregroundColor(color)
    }
    private func primary(_ label: String, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button { action() } label: { Text(label) }
            .buttonStyle(PrimaryButtonStyle(enabled: enabled)).disabled(!enabled)
    }
    /// Saltar discreto (pasos no obligatorios). Sin etiquetar nada como "opcional".
    private func skip() -> some View {
        Button { advance() } label: {
            Text("Quizá más tarde").font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.soft)
                .frame(maxWidth: .infinity).frame(height: 36)
        }.buttonStyle(.plain)
    }

    // MARK: - Navegación

    private func advance() {
        FX.tap()
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        goingBack = false
        withAnimation(.easeInOut(duration: 0.28)) { step = next }
    }
    private func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        FX.tap(); goingBack = true
        withAnimation(.easeInOut(duration: 0.28)) { step = prev }
    }
    private func focusSoon(_ f: Field) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = f }
    }
    private func runFinish() {
        avatarIn = false; drawCheck = 0
        FX.success(sound: true)
        if reduceMotion { drawCheck = 1; avatarIn = true; return }
        withAnimation(.easeOut(duration: 0.6)) { drawCheck = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) { avatarIn = true }
    }

    private func commit() {
        var acc = Account(name: name.trimmingCharacters(in: .whitespaces), handle: normalized)
        acc.photoData = photoData
        acc.photoScale = Double(photoScale)
        acc.photoOffsetX = Double(photoOffset.width)
        acc.photoOffsetY = Double(photoOffset.height)
        store.saveAccount(acc)
        if aboutDone {
            var comp = DateComponents(); comp.year = birthYear; comp.month = 6; comp.day = 15
            if let d = Calendar.current.date(from: comp) { store.profile.birthdate = d }
            if sexSel != "No especificar" { store.profile.sex = sexSel }
        }
        if !country.isEmpty { store.profile.country = country }
        if !city.isEmpty { store.profile.city = city }
        if !gym.trimmingCharacters(in: .whitespaces).isEmpty { store.profile.gym = gym.trimmingCharacters(in: .whitespaces) }
        store.profile.goal = goalSel
        store.profile.level = levelSel
        store.profile.weeklyDays = daysSel
        store.profile.motivation = motivSel
        store.persist()
        FX.success(sound: true)
    }
}

// MARK: - Forgey (mascota original)

/// Mascota amistosa de Forge Loop: cuerpo "blob" con degradado, brillo, ojos con
/// destello y mejillas suaves. Acompaña en cada paso del onboarding.
private struct Mascot: View {
    var size: CGFloat = 110
    var wave = false
    var holdsHeart = false
    var bounceTrigger: Int = 0   // al cambiar, Forgey hace squash + cara feliz
    @State private var bob = false
    @State private var blink = false
    @State private var waveAngle = false
    @State private var squash: CGFloat = 1
    @State private var happy = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let ink = Color(hex: "16240b")

    var body: some View {
        ZStack {
            // Sombra de contacto en el suelo
            Ellipse().fill(Color.black.opacity(0.10))
                .frame(width: size * 0.66, height: size * 0.12)
                .blur(radius: 7).offset(y: size * 0.56)

            ZStack {
                // Cuerpo con degradado vertical
                BlobShape()
                    .fill(LinearGradient(colors: [Color(hex: "c2f861"), Color(hex: "8ed11d")],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(BlobShape().stroke(Color(hex: "6fa916").opacity(0.5), lineWidth: 1))
                    .frame(width: size, height: size * 1.02)
                    .shadow(color: Color(hex: "8ed11d").opacity(0.4), radius: 14, y: 10)

                // Brillo superior (gloss)
                Ellipse().fill(Color.white.opacity(0.40))
                    .frame(width: size * 0.52, height: size * 0.30)
                    .blur(radius: 9).offset(x: -size * 0.11, y: -size * 0.28)

                // Mejillas suaves
                HStack(spacing: size * 0.44) { cheek; cheek }.offset(y: size * 0.15)

                // Cara
                VStack(spacing: size * 0.10) {
                    HStack(spacing: size * 0.19) { eye; eye }
                    Smile().stroke(ink, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                        .frame(width: size * (happy ? 0.42 : 0.34), height: size * (happy ? 0.21 : 0.16))
                }.offset(y: size * 0.05)

                if wave {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: size * 0.20)).foregroundColor(Color(hex: "f2b134"))
                        .rotationEffect(.degrees(waveAngle ? 20 : -4), anchor: .bottomLeading)
                        .offset(x: size * 0.5, y: -size * 0.34)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: waveAngle)
                }
                if holdsHeart {
                    Image(systemName: "heart.fill").font(.system(size: size * 0.22)).foregroundColor(Brand.red)
                        .shadow(color: Brand.red.opacity(0.4), radius: 4, y: 2)
                        .offset(x: size * 0.46, y: -size * 0.36)
                        .scaleEffect(bob ? 1.14 : 0.94)
                }
            }
            .scaleEffect(x: 2 - squash, y: squash)   // squash & stretch al reaccionar
            .offset(y: bob ? -size * 0.03 : size * 0.03)
        }
        .frame(width: size * 1.2, height: size * 1.3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = true }
            if wave { waveAngle = true }
            scheduleBlink()
        }
        .onChange(of: bounceTrigger) { _ in react() }
    }

    // Ojo: feliz = arco "^" (ojitos contentos); normal = óvalo con destello.
    private var eye: some View {
        Group {
            if happy {
                HappyEye().stroke(ink, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                    .frame(width: size * 0.14, height: size * 0.09)
            } else {
                Capsule().fill(ink)
                    .frame(width: size * 0.115, height: blink ? size * 0.025 : size * 0.215)
                    .overlay(alignment: .top) {
                        Circle().fill(Color.white.opacity(blink ? 0 : 0.9))
                            .frame(width: size * 0.045, height: size * 0.045)
                            .offset(y: size * 0.035)
                    }
            }
        }
    }

    private func react() {
        if reduceMotion { happy = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { happy = false }; return }
        happy = true
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) { squash = 0.90 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { squash = 1.08 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { squash = 1.0 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { withAnimation(.easeInOut(duration: 0.25)) { happy = false } }
    }
    private var cheek: some View {
        Circle().fill(Color(red: 1, green: 0.46, blue: 0.46).opacity(0.5))
            .frame(width: size * 0.15, height: size * 0.15).blur(radius: size * 0.02)
    }
    private func scheduleBlink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2.5...4.5)) {
            withAnimation(.easeInOut(duration: 0.10)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.easeInOut(duration: 0.10)) { blink = false }
                scheduleBlink()
            }
        }
    }
}

/// Cuerpo "blob" simétrico y suave (más orgánico que un cuadrado redondeado).
private struct BlobShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        // Squircle suave construido con curvas (esquinas muy redondeadas, lados ligeramente abombados)
        let cx = w * 0.5
        p.move(to: CGPoint(x: cx, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.5),
                   control1: CGPoint(x: w * 0.92, y: 0), control2: CGPoint(x: w, y: h * 0.12))
        p.addCurve(to: CGPoint(x: cx, y: h),
                   control1: CGPoint(x: w, y: h * 0.9), control2: CGPoint(x: w * 0.9, y: h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.5),
                   control1: CGPoint(x: w * 0.1, y: h), control2: CGPoint(x: 0, y: h * 0.9))
        p.addCurve(to: CGPoint(x: cx, y: 0),
                   control1: CGPoint(x: 0, y: h * 0.12), control2: CGPoint(x: w * 0.08, y: 0))
        p.closeSubpath()
        return p
    }
}

/// Sonrisa (arco suave) para la mascota.
private struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 1.6))
        return p
    }
}

/// Bocadillo de Forgey: texto amable (en tinta, no gris) con una cola hacia la mascota.
private struct Bubble: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        VStack(spacing: 0) {
            Triangle().fill(Color.white).frame(width: 22, height: 11)
                .overlay(Triangle().stroke(Brand.line, lineWidth: 1).clipShape(Rectangle().offset(y: 1)))
            Text(text)
                .font(.system(size: 19, weight: .heavy)).foregroundColor(Brand.ink)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18).padding(.vertical, 14)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
        }
        .padding(.horizontal, 8)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Ojo feliz: arco "^" (ojitos contentos al reaccionar).
private struct HappyEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.midX, y: r.minY))
        return p
    }
}

/// Bocadillo que se ESCRIBE letra a letra (la pregunta "habla" como Forgey).
/// Toca para completar al instante; respeta Reduce Motion.
private struct TypingBubble: View {
    let full: String
    var typing: Bool
    var onDone: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = ""
    @State private var caret = false
    @State private var task: Task<Void, Never>?

    init(_ text: String, typing: Bool = true, onDone: (() -> Void)? = nil) {
        self.full = text; self.typing = typing; self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            Triangle().fill(Color.white).frame(width: 22, height: 11)
                .overlay(Triangle().stroke(Brand.line, lineWidth: 1).clipShape(Rectangle().offset(y: 1)))
            HStack(alignment: .center, spacing: 2) {
                Text(shown).font(.system(size: 19, weight: .heavy)).foregroundColor(Brand.ink)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if typing && shown.count < full.count {
                    Capsule().fill(Brand.ink).frame(width: 2, height: 18).opacity(caret ? 1 : 0)
                        .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { caret = true } }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear { start() }
        .onDisappear { task?.cancel() }
    }

    private func start() {
        if !typing || reduceMotion { shown = full; onDone?(); return }
        shown = ""
        // Ritmo natural: ~45 ms/letra (con tope para frases largas) + pausa al final de frase.
        let base = min(0.048, 1.6 / Double(max(1, full.count)))
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)   // respira antes de empezar
            for ch in full {
                if Task.isCancelled { return }
                shown.append(ch)
                var d = base
                if ".!?…".contains(ch) { d += 0.22 }
                else if ",;".contains(ch) { d += 0.12 }
                try? await Task.sleep(nanoseconds: UInt64(d * 1_000_000_000))
            }
            onDone?()
        }
    }
    private func finish() { task?.cancel(); if shown != full { shown = full }; onDone?() }
}

/// Tarjeta de respuesta de selección única (estilo conversacional).
private struct SelectCard: View {
    let emoji: String
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 24)).scaleEffect(selected ? 1.18 : 1).frame(width: 34)
                Text(label).font(.system(size: 17, weight: .heavy))
                    .foregroundColor(selected ? Color(hex: "10150a") : Brand.ink)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Color(hex: "10150a") : Brand.line)
            }
            .padding(.horizontal, 16).frame(minHeight: 60).frame(maxWidth: .infinity)
            .background(selected ? Brand.green : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? Color.clear : Brand.line))
            .shadow(color: selected ? Brand.green.opacity(0.35) : .clear, radius: 9, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selected)
    }
}

/// Chip de reacción de Forgey ("¡A por esos músculos!").
private struct ReactionChip: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Brand.greenSoft).clipShape(Capsule())
            .overlay(Capsule().stroke(Brand.green.opacity(0.45)))
            .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
    }
}

/// Encuadre manual de la foto (arrastrar + pellizcar) durante el onboarding.
/// Devuelve escala y desplazamiento al estado del onboarding (no toca la cuenta todavía).
private struct OnboardingPhotoFramer: View {
    let data: Data
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var lastScale: CGFloat = 1
    @State private var lastOffset: CGSize = .zero
    private let editSize: CGFloat = 240   // mismo espacio que MeAvatar para que el encuadre coincida

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Arrastra y pellizca para encuadrar").font(.footnote).foregroundColor(Brand.muted)
                if let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .scaleEffect(scale).offset(offset)
                        .frame(width: editSize, height: editSize).clipShape(Circle())
                        .overlay(Circle().stroke(Brand.green, lineWidth: 3))
                        .contentShape(Circle())
                        .gesture(SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { scale = max(1, min(4, lastScale * $0)) }
                                .onEnded { _ in lastScale = scale },
                            DragGesture()
                                .onChanged { offset = CGSize(width: lastOffset.width + $0.translation.width,
                                                             height: lastOffset.height + $0.translation.height) }
                                .onEnded { _ in lastOffset = offset }))
                }
                Button { onDone(); dismiss() } label: { Text("Listo") }.buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding(20).background(Brand.bg)
            .navigationTitle("Encuadra tu foto").navigationBarTitleDisplayMode(.inline)
            .onAppear { lastScale = scale; lastOffset = offset }
        }
    }
}

// MARK: - Encuesta del onboarding (preguntas propias)

private struct SurveyOption { let emoji: String; let label: String }
private struct SurveyQuestion {
    let prompt: String
    let options: [SurveyOption]
    let reaction: (String) -> String
}

private enum OnboardingSurvey {
    static let goal = SurveyQuestion(
        prompt: "¡Cuéntame un poco de ti! No hay respuestas malas 😉 ¿Cuál es tu objetivo?",
        options: [.init(emoji: "💪", label: "Ganar músculo"), .init(emoji: "🔥", label: "Perder grasa"),
                  .init(emoji: "🏋️", label: "Ganar fuerza"), .init(emoji: "⚡", label: "Mantenerme en forma"),
                  .init(emoji: "🧘", label: "Salud y bienestar")],
        reaction: { l in
            switch l {
            case "Ganar músculo": return "¡A por esos músculos! 💪"
            case "Perder grasa": return "¡Vamos a quemar! 🔥"
            case "Ganar fuerza": return "¡Más fuerte cada día! 🏋️"
            case "Mantenerme en forma": return "¡La constancia es la clave! ⚡"
            default: return "¡Tu cuerpo te lo agradecerá! 🧘"
            }
        })

    static let level = SurveyQuestion(
        prompt: "¿Cuánto tiempo llevas entrenando?",
        options: [.init(emoji: "🌱", label: "Acabo de empezar"), .init(emoji: "📈", label: "Menos de un año"),
                  .init(emoji: "💯", label: "Entre 1 y 3 años"), .init(emoji: "🔥", label: "Más de 3 años")],
        reaction: { l in
            switch l {
            case "Acabo de empezar": return "¡Bienvenido/a al viaje! 🌱"
            case "Menos de un año": return "¡Buen momento para crecer!"
            case "Entre 1 y 3 años": return "¡Ya sabes lo que es bueno! 👌"
            default: return "¡Toda una bestia! 🔥"
            }
        })

    static let days = SurveyQuestion(
        prompt: "¿Cuántos días quieres entrenar a la semana?",
        options: [.init(emoji: "☕️", label: "1-2 días"), .init(emoji: "🗓️", label: "3 días"),
                  .init(emoji: "🔁", label: "4 días"), .init(emoji: "🚀", label: "5 o más")],
        reaction: { l in
            switch l {
            case "1-2 días": return "Constancia > intensidad ☕️"
            case "3 días": return "El clásico que funciona 👌"
            case "4 días": return "¡Buen ritmo!"
            default: return "¡Qué máquina! 🚀"
            }
        })

    static let motivation = SurveyQuestion(
        prompt: "Última 🔥 ¿Qué es lo que más te mueve?",
        options: [.init(emoji: "🪞", label: "Verme mejor"), .init(emoji: "🏆", label: "Superarme cada día"),
                  .init(emoji: "😌", label: "Despejar la mente"), .init(emoji: "🤝", label: "Entrenar con gente"),
                  .init(emoji: "💯", label: "Crear el hábito")],
        reaction: { l in
            switch l {
            case "Verme mejor": return "¡Yo tampoco salgo del espejo! 😄"
            case "Superarme cada día": return "¡Esa mentalidad! 🏆"
            case "Despejar la mente": return "El gym también es mi terapia 😌"
            case "Entrenar con gente": return "¡Mejor en equipo! 🤝"
            default: return "Paso a paso, ¡así se hace! 💯"
            }
        })
}
