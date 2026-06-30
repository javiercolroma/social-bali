import SwiftUI
import PhotosUI

/// Acompañamiento cálido para usuarios nuevos: Forgey (la mascota) te guía con una
/// pregunta amable por pantalla. Solo para cuentas nuevas (editar usa `AccountSetupView`).
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var health = HealthManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Step: Int, CaseIterable { case welcome, name, handle, photo, about, place, health, done }
    private enum Field { case name, handle }

    @State private var step: Step = .welcome
    @State private var goingBack = false
    @FocusState private var focus: Field?

    // Datos (viven aquí para no perderlos al volver atrás)
    @State private var name = ""
    @State private var handle = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var birthYear = 1998
    @State private var sexSel = "No especificar"
    @State private var aboutDone = false
    @State private var country = "España"
    @State private var city = ""
    @State private var gym = ""

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
            Bubble("¡Hola! Soy Forgey 💪 Voy a acompañarte a montar tu perfil.")
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

    private var photoStep: some View {
        layout {
            Bubble(firstName.isEmpty ? "¿Le ponemos una foto?" : "\(firstName), ¿le ponemos cara?")
            PhotoPickerLabel(item: $pickerItem, onPicked: { photoData = $0; Haptics.soft() }) {
                ZStack(alignment: .bottomTrailing) {
                    if let d = photoData, let ui = UIImage(data: d) {
                        Image(uiImage: ui).resizable().scaledToFill().frame(width: 150, height: 150).clipShape(Circle())
                    } else {
                        ZStack {
                            Circle().fill(Brand.chip).frame(width: 150, height: 150)
                            Image(systemName: "camera.fill").font(.system(size: 40)).foregroundColor(Brand.soft)
                        }
                    }
                    Image(systemName: "plus").font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Brand.ink).padding(11).background(Brand.green).clipShape(Circle())
                        .overlay(Circle().stroke(Brand.bg, lineWidth: 4))
                }
            }
        } actions: {
            primary(photoData == nil ? "Elegir foto" : "Usar esta foto") { advance() }
            skip()
        }
    }

    private var aboutStep: some View {
        layout {
            Mascot(size: 88)
            Bubble("Cuéntame un poco sobre ti")
            HStack(spacing: 0) {
                Picker("Año", selection: $birthYear) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }.pickerStyle(.wheel).frame(width: 110).clipped()
                Picker("Género", selection: $sexSel) {
                    ForEach(sexes, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.wheel).frame(maxWidth: .infinity).clipped()
            }
            .frame(height: 150)
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
            Bubble("¿Dónde sueles entrenar?")
            VStack(spacing: 10) {
                CountryField(label: "", selected: country) { country = $0 }
                CitySearchField(label: "", selected: city, country: country) { city = $0 }
                HStack(spacing: 10) {
                    Image(systemName: "dumbbell.fill").foregroundColor(Brand.soft)
                    TextField("Tu gimnasio", text: $gym).font(.system(size: 16, weight: .semibold)).tint(Brand.ink)
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
            Bubble(health.isAvailable ? "¿Conectamos con Salud para ver tu pulso en cada serie?"
                                       : "Cuando tengas el iPhone a mano podrás conectar Salud desde tu perfil.")
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
        Account(name: name.trimmingCharacters(in: .whitespaces), handle: normalized, photoData: photoData)
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
        store.saveAccount(acc)
        if aboutDone {
            var comp = DateComponents(); comp.year = birthYear; comp.month = 6; comp.day = 15
            if let d = Calendar.current.date(from: comp) { store.profile.birthdate = d }
            if sexSel != "No especificar" { store.profile.sex = sexSel }
        }
        if !country.isEmpty { store.profile.country = country }
        if !city.isEmpty { store.profile.city = city }
        if !gym.trimmingCharacters(in: .whitespaces).isEmpty { store.profile.gym = gym.trimmingCharacters(in: .whitespaces) }
        store.persist()
        FX.success(sound: true)
    }
}

// MARK: - Forgey (mascota original)

/// Mascota amistosa de Forge Loop: cuerpo verde redondeado, ojos que parpadean,
/// sonrisa y mejillas. Acompaña en cada paso del onboarding.
private struct Mascot: View {
    var size: CGFloat = 110
    var wave = false
    var holdsHeart = false
    @State private var bob = false
    @State private var blink = false
    @State private var waveAngle = false

    var body: some View {
        ZStack {
            // Cuerpo
            RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                .fill(Brand.green)
                .frame(width: size, height: size * 0.94)
                .shadow(color: Brand.green.opacity(0.35), radius: 12, y: 8)
            // Cara
            VStack(spacing: size * 0.11) {
                HStack(spacing: size * 0.20) {
                    eye; eye
                }
                Smile().stroke(Color(hex: "10150a"), style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
                    .frame(width: size * 0.30, height: size * 0.15)
            }
            .offset(y: size * 0.02)
            // Mejillas
            HStack(spacing: size * 0.46) {
                cheek; cheek
            }.offset(y: size * 0.12)
            // Brazo que saluda / corazón
            if wave {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: size * 0.22))
                    .foregroundColor(Color(hex: "10150a"))
                    .rotationEffect(.degrees(waveAngle ? 18 : -6), anchor: .bottomLeading)
                    .offset(x: size * 0.52, y: -size * 0.30)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: waveAngle)
            }
            if holdsHeart {
                Image(systemName: "heart.fill").font(.system(size: size * 0.24)).foregroundColor(Brand.red)
                    .offset(x: size * 0.5, y: -size * 0.34)
                    .scaleEffect(bob ? 1.12 : 0.95)
            }
        }
        .offset(y: bob ? -size * 0.035 : size * 0.035)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { bob = true }
            if wave { waveAngle = true }
            scheduleBlink()
        }
    }

    private var eye: some View {
        Capsule().fill(Color(hex: "10150a"))
            .frame(width: size * 0.085, height: blink ? size * 0.02 : size * 0.17)
    }
    private var cheek: some View {
        Circle().fill(Color(red: 1, green: 0.45, blue: 0.45).opacity(0.45))
            .frame(width: size * 0.12, height: size * 0.12)
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
