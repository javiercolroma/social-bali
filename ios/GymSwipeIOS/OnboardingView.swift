import SwiftUI
import PhotosUI

/// Acompañamiento para usuarios nuevos: una pregunta amable por pantalla, solo con lo
/// que alimenta el club. Solo para cuentas nuevas (editar usa `AccountSetupView`).
/// Sin mascota y sin pasos de entreno: la app ya no es de fitness.
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // `birth` y `sex` estaban juntos en un solo paso `about` con DOS ruedas apiladas:
    // no se podía elegir nada, porque `.clipped()` recorta el dibujo pero NO el área
    // táctil, así que las dos ruedas (216pt intrínsecos cada una) se solapaban y se
    // robaban los toques. Una rueda por pantalla, y con su altura natural.
    // Flujo del CLUB (PRODUCT.md · Fase 1). Fuera los 4 pasos de la encuesta fitness
    // —goal, level, days, motivation—: se escribían en el perfil y NO se leían en ninguna
    // parte, o sea 4 pantallas para generar datos muertos. En su lugar entran los que
    // alimentan Discover: deportes, zona, estancia, origen, bio e intenciones.
    enum Step: Int, CaseIterable {
        case welcome, name, birth, photos, sports, arrival, stay, area, home, bio, intents, location, done
    }
    private enum Field { case name }

    @State private var step: Step = .welcome
    @State private var goingBack = false
    @FocusState private var focus: Field?

    // Datos (viven aquí para no perderlos al volver atrás)
    @State private var name = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoScale: CGFloat = 1
    @State private var photoOffset: CGSize = .zero
    @State private var showFramer = false
    /// Galería (mínimo 3 para entrar): fotos, vídeos y Live Photos.
    @State private var media: [MediaItem] = []
    /// ¿Ya está en Bali? Si no, cuándo llega (el Circle se abre al llegar).
    @State private var inBaliNow: Bool? = nil
    @State private var arrivalDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @ObservedObject private var presence = PresenceService.shared
    @State private var birthYear = 1997
    @State private var sexSel: Gender? = nil
    /// Separados a propósito: antes un solo `aboutDone` hacía que saltarse el año y
    /// pulsar Continuar en el sexo guardase 1997 (el valor por defecto de la rueda).
    /// Con la regla de 18 años eso daba acceso a «Dating» con una edad inventada.
    @State private var birthDone = false
    @State private var country = ""
    @State private var city = ""

    // Identidad del club (ver SocialClub.swift). Se guardan rawValues.
    @State private var sportsSel: Set<String> = []
    @State private var areaSel: String?
    @State private var stayKindSel: String?
    @State private var stayDate = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    @State private var bioText = ""
    @State private var intentsSel: Set<String> = []

    @State private var drawCheck: CGFloat = 0
    @State private var avatarIn = false

    private var years: [Int] {
        let now = Calendar.current.component(.year, from: Date())
        return Array(1930...(now - 13))
    }

    // MARK: - Validación

    private var firstName: String {
        name.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
    }
    private var nameOK: Bool { name.trimmingCharacters(in: .whitespaces).count >= 2 }
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
        .onAppear {
            // Prefijar con Apple/Google: solo el nombre de pila (no se pide apellido).
            if name.isEmpty, let n = store.auth?.name, !n.isEmpty {
                name = n.split(separator: " ").first.map(String.init) ?? n
            }
        }
        .onChange(of: step) { _ in
            if step == .name { focusSoon(.name) } else { focus = nil }
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
                    Capsule().fill(Brand.sand.opacity(0.5))
                    Capsule().fill(Brand.accent).frame(width: max(0, geo.size.width * progress))
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
        case .birth: birthStep
        case .photos: photosStep
        case .sports: sportsStep
        case .arrival: arrivalStep
        case .stay: stayStep
        case .area: areaStep
        case .home: homeStep
        case .bio: bioStep
        case .intents: intentsStep
        case .location: locationStep
        case .done: doneStep
        }
    }

    private var welcomeStep: some View {
        layout {
            Text("BALI CIRCLE").font(.system(size: 12, weight: .bold)).tracking(3).foregroundColor(Brand.bronze)
            Question("A private club for active people in Bali")
            Text("Surf, train, explore — and meet the people doing it around you. Let's set up your profile.")
                .font(.system(size: 16)).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            primary("Start") { advance() }
        }
    }

    /// Solo el nombre de pila: el @usuario lo genera la app en silencio y nunca se muestra.
    private var nameStep: some View {
        layout {
            Question("What's your first name?")
            TextField("First name", text: $name)
                .multilineTextAlignment(.center).font(.display(26))
                .foregroundColor(Brand.ink).tint(Brand.ink)
                .textContentType(.givenName)
                .focused($focus, equals: .name).submitLabel(.next).onSubmit { if nameOK { advance() } }
                .padding(.horizontal, 14).frame(height: 58).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(focus == .name ? Brand.accent : Brand.line, lineWidth: focus == .name ? 1.8 : 1))
        } actions: {
            primary("Continue", enabled: nameOK) { advance() }
        }
    }

    private var photoStep: some View {
        layout {
            Question(firstName.isEmpty ? "Now let's put a face to the name" : "Now let's put a face to the name, \(firstName)")
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
                    Text("Pick a photo")
                        .font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.onAccent)
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Brand.accent).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                primary("Use this photo") { advance() }
                PhotoPickerLabel(item: $pickerItem, onPicked: { onPhotoPicked($0) }) {
                    Text("Pick another").font(.system(size: 14, weight: .bold)).foregroundColor(Brand.soft)
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
            .foregroundColor(Brand.onAccent).padding(11).background(Brand.accent).clipShape(Circle())
            .overlay(Circle().stroke(Brand.bg, lineWidth: 4))
    }

    /// Tras elegir foto: guarda los datos, resetea encuadre y abre el editor para encuadrar.
    /// Se deja que el selector se cierre primero y luego sube el editor (transición limpia).
    private func onPhotoPicked(_ data: Data) {
        photoData = data; photoScale = 1; photoOffset = .zero; Haptics.soft()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showFramer = true }
    }

    private var birthStep: some View {
        layout {
            Question("When were you born?")
            wheelCard {
                Picker("Year", selection: $birthYear) {
                    ForEach(years, id: \.self) {
                        Text(String($0)).font(.system(size: 20, weight: .bold)).foregroundColor(Brand.ink).tag($0)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 170)
            }
        } actions: {
            primary("Continue") { birthDone = true; advance() }
        }
    }

    // MARK: - Fotos (mínimo 3)

    private var photosStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Question("Show who you are")
                Text("Add at least 3 photos — doing what you love beats posing. Videos and Live Photos come to life on your profile.")
                    .font(.system(size: 15)).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            ScrollView { MediaGalleryEditor(items: $media).padding(.vertical, 4) }
            VStack(spacing: 4) {
                primary(media.count >= MediaRules.minToJoin ? "Continue"
                        : String(format: L10n.t("Add %lld more"), MediaRules.minToJoin - media.count),
                        enabled: media.count >= MediaRules.minToJoin) { advance() }
            }
            .padding(.bottom, 14)
        }
    }

    // MARK: - ¿Ya estás en Bali?

    private var arrivalStep: some View {
        layout {
            Question("Are you in Bali right now?")
            VStack(spacing: 10) {
                SelectCard(emoji: "🌴", label: L10n.t("Yes, I'm here"), selected: inBaliNow == true) {
                    FX.selection(); inBaliNow = true
                }
                SelectCard(emoji: "✈️", label: L10n.t("Not yet — I'm coming"), selected: inBaliNow == false) {
                    FX.selection(); inBaliNow = false
                }
                if inBaliNow == false {
                    DatePicker("Arriving on", selection: $arrivalDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                        .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    Text("You can set up everything now. Your circle opens when your location shows you're in Bali.")
                        .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.85), value: inBaliNow)
        } actions: {
            primary("Continue", enabled: inBaliNow != nil) { advance() }
        }
    }

    // MARK: - Ubicación (obligatoria)

    private var locationStep: some View {
        layout {
            Image(systemName: presence.canUseLocation ? "checkmark.circle" : "location.circle")
                .font(.system(size: 56, weight: .ultraLight)).foregroundColor(Brand.bronze)
            Question(presence.canUseLocation ? "You're all set to see who's around" : "Share your location")
            Text("It confirms you're in Bali and shows how far people are. Others only ever see a distance like “800 m” — never where you are. You can hide your distance and online status anytime.")
                .font(.system(size: 15)).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } actions: {
            if presence.canUseLocation {
                primary("Continue") { advance() }
            } else {
                primary(presence.locationDenied ? "Open Settings" : "Share my location") { presence.requestPermission() }
                if presence.locationDenied {
                    Text("Bali Circle needs your location to work.").font(.footnote).foregroundColor(Brand.muted)
                        .frame(height: 36)
                }
            }
        }
    }

    private var sexStep: some View {
        layout {
            Question("What's your gender?")
            wheelCard {
                Picker("Gender", selection: $sexSel) {
                    Text("Prefer not to say").font(.system(size: 20, weight: .bold))
                        .foregroundColor(Brand.ink).tag(Gender?.none)
                    ForEach(Gender.allCases) { g in
                        Text(g.label).font(.system(size: 20, weight: .bold))
                            .foregroundColor(Brand.ink).tag(Gender?.some(g))
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 170)
            }
        } actions: {
            primary("Continue") { advance() }
            skip()
        }
    }

    /// Tarjeta blanca que envuelve una rueda. Sin `.clipped()`: recortaba el dibujo
    /// pero no el área táctil, que es lo que rompía la selección.
    private func wheelCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
    }

    // MARK: - Pasos del club (PRODUCT.md · Fase 1 «Identidad»)
    //
    // Estos 6 pasos son los que hacen posible Discover: sin ellos la tarjeta de una
    // persona está vacía y no se puede decidir si te apetece conocerla. Se escriben en
    // INGLÉS (idioma base del producto desde 2026-09-28).

    /// Deportes: 23 opciones, así que rejilla de chips en vez de tarjetas apiladas.
    private var sportsStep: some View {
        layout {
            Question("What do you move with?")
            ChipGrid(items: Sport.curated.map { ($0.rawValue, "\($0.emoji) \($0.label)") },
                     selected: sportsSel) { raw in
                FX.selection()
                if sportsSel.contains(raw) { sportsSel.remove(raw) } else { sportsSel.insert(raw) }
            }
        } actions: {
            primary("Continue", enabled: !sportsSel.isEmpty) { advance() }
        }
    }

    /// Zona de Bali. El barrio es DECLARADO: el GPS se redondea a ~5,5 km y no distingue Canggu de
    /// Pererenan (ver SocialClub.swift).
    private var areaStep: some View {
        layout {
            Question(inBaliNow == false ? "Where in Bali will you stay?" : "Where in Bali are you based?")
            ChipGrid(items: Neighborhood.picker.map { ($0.rawValue, $0.label) },
                     selected: areaSel.map { [$0] } ?? []) { raw in
                FX.selection(); areaSel = (areaSel == raw) ? nil : raw
            }
        } actions: {
            primary("Continue", enabled: areaSel != nil) { advance() }
        }
    }

    /// Estancia. Es de lo más importante del perfil: cambia por completo la utilidad de
    /// una conexión saber si alguien vive aquí o se va el martes.
    private var stayStep: some View {
        layout {
            Question(inBaliNow == false ? "How long will you stay?" : "How long are you around?")
            VStack(spacing: 10) {
                ForEach(StayKind.allCases) { k in
                    SelectCard(emoji: k == .livingHere ? "🏝️" : (k == .longTerm ? "🗓️" : "✈️"),
                               label: k.label, selected: stayKindSel == k.rawValue) {
                        FX.selection()
                        stayKindSel = k.rawValue
                    }
                }
                if stayKindSel == StayKind.until.rawValue {
                    DatePicker("Leaving on", selection: $stayDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Brand.ink)
                        .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.85), value: stayKindSel)
        } actions: {
            primary("Continue", enabled: stayKindSel != nil) { advance() }
        }
    }

    /// De dónde eres (≠ dónde estás). Es lo que da el «Barcelona 🇪🇸» de la tarjeta.
    /// Escribe también `country`/`city`, que son los que alimentan la banderita ya existente.
    private var homeStep: some View {
        layout {
            Question("And where are you from?")
            VStack(spacing: 10) {
                CountryField(label: "", selected: country) { country = $0 }
                CitySearchField(label: "", selected: city, country: country) { city = $0 }
            }
        } actions: {
            primary("Continue") { advance() }
            skip()
        }
    }

    /// Bio de una línea: lo que hace que alguien piense «me apetecería conocer a esta
    /// persona». Es el campo con más peso de la tarjeta de Discover.
    private var bioStep: some View {
        layout {
            Question("Sum yourself up in one line")
            VStack(alignment: .leading, spacing: 8) {
                TextField("Sunrise surf → coffee → work.", text: $bioText, axis: .vertical)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Brand.ink).tint(Brand.ink)
                    .lineLimit(2...4)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
                    .onChange(of: bioText) { v in
                        if v.count > 140 { bioText = String(v.prefix(140)) }
                    }
                Text("\(bioText.count)/140").font(.caption2).foregroundColor(Brand.soft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } actions: {
            primary("Continue", enabled: !bioText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { advance() }
        }
    }

    /// Qué tipo de conexiones busca. Multi-selección y sin compartimentos: una sola
    /// comunidad. Va al final porque es lo que más compromete.
    private var intentsStep: some View {
        layout {
            Question("What are you open to?")
            VStack(spacing: 10) {
                ForEach(ConnectionIntent.allCases) { i in
                    let locked = i == .dating && !canDate
                    SelectCard(emoji: i == .training ? "🏋️" : (i == .friends ? "🤝" : "✨"),
                               label: i.label, selected: intentsSel.contains(i.rawValue) && !locked) {
                        FX.selection()
                        if intentsSel.contains(i.rawValue) { intentsSel.remove(i.rawValue) }
                        else { intentsSel.insert(i.rawValue) }
                    }
                    .disabled(locked).opacity(locked ? 0.45 : 1)
                }
                if !canDate {
                    Text(birthDone ? "Dating is for members 18 and over."
                                   : "Dating is for members 18 and over. Add your birth year to turn it on.")
                        .font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                }
                Text("You can pick more than one — and change it later.")
                    .font(.footnote).foregroundColor(Brand.muted)
                    .multilineTextAlignment(.center).padding(.top, 2)
            }
        } actions: {
            primary("Continue", enabled: !intentsSel.subtracting(canDate ? [] : [ConnectionIntent.dating.rawValue]).isEmpty) { FX.success(); advance() }
        }
    }

    private var doneStep: some View {
        layout {
            ZStack {
                Circle().stroke(Brand.sand, lineWidth: 7).frame(width: 150, height: 150)
                Circle().trim(from: 0, to: drawCheck).stroke(Brand.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 150, height: 150)
                Group {
                    if let m = media.first { RemoteFill(url: m.url) } else { MeAvatar(account: previewAccount, size: 116) }
                }
                .frame(width: 116, height: 116).clipShape(Circle())
                .scaleEffect(avatarIn ? 1 : 0.4).opacity(avatarIn ? 1 : 0)
            }
            Question(firstName.isEmpty ? "You're all set!" : "You're all set, \(firstName)!")
        } actions: {
            primary("Enter Bali Circle") { commit() }
        }
    }

    private var previewAccount: Account {
        var a = Account(name: firstName, handle: "", photoData: photoData)
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

    private func primary(_ label: String, enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        // LocalizedStringKey y no String: `Text(String)` NO localiza.
        Button { action() } label: { Text(LocalizedStringKey(label)) }
            .buttonStyle(PrimaryButtonStyle(enabled: enabled)).disabled(!enabled)
    }
    /// Saltar discreto (pasos no obligatorios). Sin etiquetar nada como "opcional".
    private func skip() -> some View {
        Button { advance() } label: {
            Text("Maybe later").font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.soft)
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

    /// Solo el año (la rueda no pide más): se guarda a mitad de año, como siempre.
    private var chosenBirthdate: Date? {
        guard birthDone else { return nil }
        var comp = DateComponents(); comp.year = birthYear; comp.month = 6; comp.day = 15
        return Calendar.current.date(from: comp)
    }

    private var canDate: Bool { AgeGate.isAdult(chosenBirthdate) }

    private func commit() {
        // El @usuario (único en el servidor) se genera aquí en silencio: la UI no lo pide ni lo enseña.
        var acc = Account(name: firstName, handle: AppStore.generateHandle(from: firstName))
        acc.photoData = photoData
        acc.photoScale = Double(photoScale)
        acc.photoOffsetX = Double(photoOffset.width)
        acc.photoOffsetY = Double(photoOffset.height)
        if let d = chosenBirthdate { store.profile.birthdate = d }
        if let g = sexSel { store.profile.sex = g.rawValue }
        // De dónde eres. Se escribe también en country/city (legado) porque son los que
        // alimentan la banderita que ya se pinta en el feed y los avatares.
        if !country.isEmpty { store.profile.country = country; store.profile.homeCountry = country }
        if !city.isEmpty { store.profile.city = city; store.profile.homeCity = city }

        // Identidad del club (PRODUCT.md · Fase 1). Los deportes se guardan en el orden
        // curado, no en el del Set, para que la tarjeta se vea igual en cada render.
        store.profile.sports = Sport.curated.map(\.rawValue).filter(sportsSel.contains)
        store.profile.neighborhood = areaSel
        store.profile.stayKind = stayKindSel
        store.profile.stayUntil = (stayKindSel == StayKind.until.rawValue) ? stayDate : nil
        let bio = bioText.trimmingCharacters(in: .whitespacesAndNewlines)
        store.profile.bio = bio.isEmpty ? nil : bio
        store.profile.intents = ConnectionIntent.allCases.map(\.rawValue).filter(intentsSel.contains)
            .filter { $0 != ConnectionIntent.dating.rawValue || canDate }
        store.profile.media = media
        store.profile.arrivalDate = inBaliNow == false ? arrivalDate : nil

        // La cuenta se guarda AL FINAL: `saveAccount` sincroniza con el servidor, y
        // antes se llamaba al principio, con el perfil del club aún sin rellenar.
        store.saveAccount(acc)
        FX.success(sound: true)
    }
}

/// Pregunta de cada paso: titular grande y centrado.
private struct Question: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(LocalizedStringKey(text))
            .font(.display(30)).foregroundColor(Brand.ink)
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }
}

/// Tarjeta de respuesta de selección única (estilo conversacional).
/// Rejilla de chips con ajuste automático: para listas largas (23 deportes, 14 barrios)
/// donde apilar `SelectCard` daría una pantalla interminable de scroll.
/// `items` = (valor guardado, etiqueta visible).
private struct ChipGrid: View {
    let items: [(String, String)]
    let selected: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.0) { value, label in
                let on = selected.contains(value)
                Button {
                    onTap(value)
                } label: {
                    Text(label)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(on ? Brand.onAccent : Brand.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 12).frame(height: 42).frame(maxWidth: .infinity)
                        .background(on ? Brand.accent : Color.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(on ? Color.clear : Brand.line))
                        .shadow(color: on ? Brand.accent.opacity(0.30) : .clear, radius: 6, y: 3)
                }
                .buttonStyle(PressableButtonStyle())
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: on)
            }
        }
    }
}

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
                    .foregroundColor(selected ? Brand.ink : Brand.ink)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? Brand.onAccent : Brand.line)
            }
            .padding(.horizontal, 16).frame(minHeight: 60).frame(maxWidth: .infinity)
            .background(selected ? Brand.accent : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? Color.clear : Brand.line))
            .shadow(color: selected ? Brand.accent.opacity(0.35) : .clear, radius: 9, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selected)
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
                Text("Drag and pinch to frame").font(.footnote).foregroundColor(Brand.muted)
                if let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .scaleEffect(scale).offset(offset)
                        .frame(width: editSize, height: editSize).clipShape(Circle())
                        .overlay(Circle().stroke(Brand.accent, lineWidth: 3))
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
                Button { onDone(); dismiss() } label: { Text("Done") }.buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding(20).background(Brand.bg)
            .navigationTitle("Frame your photo").navigationBarTitleDisplayMode(.inline)
            .onAppear { lastScale = scale; lastOffset = offset }
        }
    }
}
