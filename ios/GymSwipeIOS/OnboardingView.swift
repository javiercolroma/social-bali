import SwiftUI
import PhotosUI

/// Acompañamiento cálido para usuarios nuevos: una pregunta amable por pantalla,
/// pasos opcionales saltables y un cierre personal. Solo para cuentas nuevas
/// (la edición de cuenta sigue usando `AccountSetupView`).
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject private var health = HealthManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Step: Int, CaseIterable { case welcome, name, handle, photo, about, place, health, done }
    private enum Field { case name, handle }

    @State private var step: Step = .welcome
    @State private var goingBack = false
    @FocusState private var focus: Field?

    // Todos los datos viven aquí para no perderlos al volver atrás.
    @State private var name = ""
    @State private var handle = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var birthdate: Date?
    @State private var sex = ""
    @State private var country = "España"
    @State private var city = ""
    @State private var gym = ""

    @State private var showBirthPicker = false
    @State private var birthSelection = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var drawCheck: CGFloat = 0
    @State private var avatarIn = false

    private let sexes = ["Hombre", "Mujer", "Otro", "Prefiero no decirlo"]

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
                ZStack {
                    stepBody
                        .id(step)
                        .transition(slide)
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .sheet(isPresented: $showBirthPicker) { birthPicker }
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

    // MARK: - Top bar (progreso + atrás)

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
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.muted)
                            .frame(width: 36, height: 36)
                    }
                }
                Spacer()
            }
            .frame(height: 36)
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
        scaffold {
            VStack(spacing: 18) {
                Spacer()
                ZStack {
                    Circle().fill(Brand.greenSoft).frame(width: 104, height: 104)
                    Image(systemName: "dumbbell.fill").font(.system(size: 44, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                }
                title("Bienvenido a Forge Loop")
                subtitle("Vamos a preparar tu espacio sin prisa, una cosa cada vez. Tú marcas el ritmo.")
                Spacer()
            }
        } actions: {
            primary("Empezar") { advance() }
        }
    }

    private var nameStep: some View {
        scaffold {
            heading("¿Cómo te llamas?", "Así te saludaremos cada vez que entres a entrenar.")
            TextField("Tu nombre", text: $name)
                .font(.system(size: 18, weight: .semibold)).focused($focus, equals: .name)
                .submitLabel(.next).onSubmit { if nameOK { advance() } }
                .padding(.horizontal, 14).frame(height: 54).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(focus == .name ? Brand.green : Brand.line, lineWidth: focus == .name ? 1.6 : 1))
        } actions: {
            primary("Continuar", enabled: nameOK) { advance() }
        }
    }

    private var handleStep: some View {
        scaffold {
            heading(firstName.isEmpty ? "Elige tu @usuario" : "Genial, \(firstName). Elige tu @usuario",
                    "Es tu nombre en la comunidad: tus colegas de gimnasio te encontrarán por él.")
            HStack(spacing: 2) {
                Text("@").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.soft)
                TextField("tu_usuario", text: $handle).font(.system(size: 18, weight: .semibold))
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focus, equals: .handle)
                    .submitLabel(.next).onSubmit { if handleOK { advance() } }
            }
            .padding(.horizontal, 14).frame(height: 54).background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(focus == .handle ? Brand.green : Brand.line, lineWidth: focus == .handle ? 1.6 : 1))
            if !normalized.isEmpty, let err = handleError {
                hint(err, "exclamationmark.circle.fill", Color(hex: "c14b46"))
            } else if !normalized.isEmpty {
                hint("@\(normalized) disponible", "checkmark.circle.fill", Color(hex: "4b8a1f"))
            }
        } actions: {
            primary("Continuar", enabled: handleOK) { advance() }
        }
    }

    private var photoStep: some View {
        scaffold {
            heading(firstName.isEmpty ? "Ponle cara a tu perfil" : "Ponle cara, \(firstName)",
                    "Una foto ayuda a que te reconozcan en la pista. Puedes añadirla cuando quieras.", optional: true)
            HStack {
                Spacer()
                PhotoPickerLabel(item: $pickerItem, onPicked: { photoData = $0; Haptics.soft() }) {
                    ZStack(alignment: .bottomTrailing) {
                        if let d = photoData, let ui = UIImage(data: d) {
                            Image(uiImage: ui).resizable().scaledToFill().frame(width: 120, height: 120).clipShape(Circle())
                        } else {
                            ZStack {
                                Circle().fill(Brand.chip).frame(width: 120, height: 120)
                                Image(systemName: "person.fill").font(.system(size: 46)).foregroundColor(Brand.soft)
                            }
                        }
                        Image(systemName: "camera.fill").font(.system(size: 14, weight: .bold))
                            .foregroundColor(Brand.ink).padding(9).background(Brand.green).clipShape(Circle())
                            .overlay(Circle().stroke(Brand.bg, lineWidth: 3))
                    }
                }
                Spacer()
            }
        } actions: {
            primary(photoData == nil ? "Añadir foto" : "Usar esta foto") { advance() }
            skip("Ahora no")
        }
    }

    private var aboutStep: some View {
        scaffold {
            heading("Cuéntanos un poco de ti",
                    "Nos sirve para comparar tu progreso de forma justa con gente como tú. Solo si te apetece.", optional: true)
            Button { birthSelection = birthdate ?? birthSelection; showBirthPicker = true } label: {
                HStack {
                    Image(systemName: "calendar").foregroundColor(Brand.soft)
                    Text(birthdate == nil ? "Fecha de nacimiento" : birthText)
                        .foregroundColor(birthdate == nil ? Brand.soft : Brand.ink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(Brand.soft)
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
            }.buttonStyle(.plain)
            OnboardingChips(options: sexes, selected: $sex)
        } actions: {
            primary("Continuar") { advance() }
            skip("Omitir este paso")
        }
    }

    private var placeStep: some View {
        scaffold {
            heading("¿Dónde entrenas?",
                    "Para encontrar compañeros y rankings cerca de ti. Lo tuyo, cuando quieras.", optional: true)
            CountryField(label: "País", selected: country) { country = $0 }
            CitySearchField(label: "Ciudad", selected: city, country: country) { city = $0 }
            VStack(alignment: .leading, spacing: 5) {
                Text("GIMNASIO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                TextField("Tu gimnasio", text: $gym)
                    .padding(.horizontal, 12).frame(height: 48).background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.line))
            }
        } actions: {
            primary("Continuar") { advance() }
            skip("Ahora no")
        }
    }

    private var healthStep: some View {
        scaffold {
            VStack(spacing: 18) {
                Spacer()
                ZStack {
                    Circle().fill(Brand.redSoft).frame(width: 104, height: 104)
                    Image(systemName: "heart.fill").font(.system(size: 44)).foregroundColor(Brand.red)
                        .scaleEffect(avatarIn ? 1.08 : 1)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: avatarIn)
                }
                if health.isAvailable {
                    title("Tu pulso, en directo")
                    subtitle("Conecta Salud y verás tus pulsaciones en cada serie. Solo leemos tu ritmo cardíaco, y puedes cambiarlo luego.")
                } else {
                    title("Tu pulso, en directo")
                    subtitle("Podrás conectar Salud desde tu perfil cuando tengas el iPhone a mano.")
                }
                Spacer()
            }
        } actions: {
            if health.isAvailable && !health.connected {
                primary("Conectar con Salud") { Task { _ = await health.connect(); advance() } }
                skip("Ahora no")
            } else {
                primary(health.connected ? "Salud conectada ✓" : "Continuar") { advance() }
            }
        }
        .onAppear { avatarIn = true }
    }

    private var doneStep: some View {
        scaffold {
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    Circle().stroke(Brand.greenSoft, lineWidth: 6).frame(width: 132, height: 132)
                    Circle().trim(from: 0, to: drawCheck).stroke(Brand.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 132, height: 132)
                    MeAvatar(account: previewAccount, size: 104)
                        .scaleEffect(avatarIn ? 1 : 0.4).opacity(avatarIn ? 1 : 0)
                }
                title(firstName.isEmpty ? "¡Todo listo!" : "Listo, \(firstName)")
                subtitle("Tu espacio ya está montado. Es hora de levantar algo pesado.")
                Spacer()
            }
        } actions: {
            primary("Entrar a Forge Loop") { commit() }
        }
    }

    /// Cuenta provisional solo para previsualizar el avatar en la pantalla final.
    private var previewAccount: Account {
        Account(name: name.trimmingCharacters(in: .whitespaces), handle: normalized, photoData: photoData)
    }

    // MARK: - Scaffold

    @ViewBuilder
    private func scaffold<C: View, A: View>(@ViewBuilder content: () -> C, @ViewBuilder actions: () -> A) -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            VStack(spacing: 6) { actions() }
        }
        .padding(.top, 24).padding(.bottom, 14)
    }

    private func heading(_ t: String, _ s: String, optional: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if optional {
                Text("OPCIONAL").font(.system(size: 10, weight: .heavy)).tracking(0.5).foregroundColor(Brand.soft)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Brand.chip).clipShape(Capsule())
            }
            title(t); subtitle(s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(_ t: String) -> some View {
        Text(t).font(.system(size: 27, weight: .heavy)).foregroundColor(Brand.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func subtitle(_ s: String) -> some View {
        Text(s).font(.system(size: 15)).foregroundColor(Brand.muted).fixedSize(horizontal: false, vertical: true)
    }
    private func hint(_ t: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 5) { Image(systemName: icon); Text(t) }
            .font(.system(size: 13, weight: .semibold)).foregroundColor(color)
    }

    private func primary(_ label: String, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        Button { action() } label: { Text(label) }
            .buttonStyle(PrimaryButtonStyle(enabled: enabled)).disabled(!enabled)
    }
    private func skip(_ label: String) -> some View {
        Button { advance() } label: {
            Text(label).font(.system(size: 15, weight: .bold)).foregroundColor(Brand.soft)
                .frame(maxWidth: .infinity).frame(height: 38)
        }.buttonStyle(.plain)
    }

    private var birthText: String {
        guard let b = birthdate else { return "" }
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "d 'de' MMMM, yyyy"
        return f.string(from: b)
    }

    private var birthPicker: some View {
        let minBirth = Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date()
        return NavigationStack {
            VStack {
                DatePicker("Fecha de nacimiento", selection: $birthSelection, in: minBirth...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical).environment(\.locale, Locale(identifier: "es_ES")).padding()
                Spacer()
            }
            .navigationTitle("Tu fecha de nacimiento").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Listo") { birthdate = birthSelection; showBirthPicker = false }.fontWeight(.heavy)
            } }
        }.presentationDetents([.medium, .large])
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
        // Solo escribimos los campos de perfil que el usuario rellenó.
        if let birthdate { store.profile.birthdate = birthdate }
        if !sex.isEmpty { store.profile.sex = sex }
        if !country.isEmpty { store.profile.country = country }
        if !city.isEmpty { store.profile.city = city }
        if !gym.trimmingCharacters(in: .whitespaces).isEmpty { store.profile.gym = gym.trimmingCharacters(in: .whitespaces) }
        store.persist()
        FX.success(sound: true)
    }
}

/// Chips seleccionables (selección única) — toque suave para sexo/género.
private struct OnboardingChips: View {
    let options: [String]
    @Binding var selected: String
    private let cols = [GridItem(.adaptive(minimum: 110), spacing: 8)]
    var body: some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(options, id: \.self) { opt in
                let on = selected == opt
                Button {
                    FX.selection(); selected = on ? "" : opt
                } label: {
                    Text(opt).font(.system(size: 14, weight: .heavy)).foregroundColor(on ? Color(hex: "10150a") : Brand.ink)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(on ? Brand.greenSoft : Brand.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Brand.green : Brand.line, lineWidth: on ? 1.5 : 1))
                }.buttonStyle(.plain)
            }
        }
    }
}
