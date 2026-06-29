import SwiftUI
import UIKit
import PhotosUI

// MARK: - Editar perfil (datos personales + redes)

struct EditProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var editingData: Data?
    @State private var showEditor = false
    @State private var showBirthPicker = false
    @State private var birthSelection = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

    private var ageText: String {
        guard let b = store.profile.birthdate else { return "" }
        let years = Calendar.current.dateComponents([.year], from: b, to: Date()).year ?? 0
        return "\(years)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PanelCard {
                    HStack { Spacer()
                        PhotoPickerLabel(item: $pickerItem, onPicked: { data in
                            var acc = store.account ?? Account(name: "", handle: "")
                            acc.photoData = data; acc.photoScale = 1; acc.photoOffsetX = 0; acc.photoOffsetY = 0
                            store.saveAccount(acc)
                            editingData = data; showEditor = true
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                MeAvatar(account: store.account, size: 84)
                                Image(systemName: "camera.fill").font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Brand.ink).padding(6).background(Brand.green).clipShape(Circle())
                            }
                        }
                        Spacer()
                    }
                    field("Nombre", binding: accountName)
                    handleField
                }

                PanelCard {
                    Text("DATOS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    MenuField(label: "Sexo", placeholder: "Elegir",
                              selected: store.profile.sex,
                              options: ["Hombre", "Mujer", "Otro"].map { ($0, $0) }) {
                        store.profile.sex = $0; store.persist()
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("FECHA DE NACIMIENTO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        Button { birthSelection = store.profile.birthdate ?? birthSelection; showBirthPicker = true } label: {
                            HStack {
                                Text(birthLabel).foregroundColor(store.profile.birthdate == nil ? Brand.soft : Brand.ink)
                                Spacer()
                                if !ageText.isEmpty { Text("\(ageText) años").font(.caption).fontWeight(.heavy).foregroundColor(Color(hex: "4b6211")) }
                                Image(systemName: "calendar").font(.caption).foregroundColor(Brand.soft)
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 12).frame(height: 44).background(Brand.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    CountryField(label: "País", selected: store.profile.country) { store.profile.country = $0; store.persist() }
                    CitySearchField(label: "Ciudad", selected: store.profile.city, country: store.profile.country) { store.profile.city = $0; store.persist() }
                    field("Zona / barrio (opcional)", binding: Binding(get: { store.profile.region ?? "" }, set: { store.profile.region = $0; store.persist() }))
                    field("Gimnasio", binding: Binding(get: { store.profile.gym }, set: { store.profile.gym = $0; store.persist() }))
                }

                PanelCard {
                    Text("REDES SOCIALES").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    socialField("Instagram", "camera.circle.fill", Binding(get: { store.profile.instagram ?? "" }, set: { store.profile.instagram = clean($0); store.persist() }))
                    socialField("TikTok", "music.note", Binding(get: { store.profile.tiktok ?? "" }, set: { store.profile.tiktok = clean($0); store.persist() }))
                    socialField("X (Twitter)", "at", Binding(get: { store.profile.twitter ?? "" }, set: { store.profile.twitter = clean($0); store.persist() }))
                    Text("Aparecerán como tarjetas en tu perfil que llevan directo a tus redes.")
                        .font(.caption2).foregroundColor(Brand.soft)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
        .navigationTitle("Editar perfil").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            if let d = editingData { PhotoEditorView(data: d).environmentObject(store) }
        }
        .sheet(isPresented: $showBirthPicker) {
            NavigationStack {
                VStack {
                    DatePicker("Fecha de nacimiento", selection: $birthSelection, in: minBirth...Date(), displayedComponents: .date)
                        .datePickerStyle(.wheel).labelsHidden().padding()
                    Spacer()
                }
                .background(Brand.bg)
                .navigationTitle("Fecha de nacimiento").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancelar") { showBirthPicker = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Listo") { store.profile.birthdate = birthSelection; store.persist(); showBirthPicker = false }.fontWeight(.heavy)
                    }
                }
            }
            .presentationDetents([.height(360)])
        }
    }

    private func clean(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        return t.isEmpty ? nil : t
    }

    private var accountName: Binding<String> {
        Binding(get: { store.account?.name ?? "" },
                set: { var a = store.account ?? Account(name: "", handle: ""); a.name = $0; store.saveAccount(a) })
    }

    private var handleField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("USUARIO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            HStack(spacing: 2) {
                Text("@").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.soft)
                TextField("tu_usuario", text: Binding(
                    get: { store.account?.handle ?? "" },
                    set: { var a = store.account ?? Account(name: "", handle: ""); a.handle = normalizeHandle($0); store.saveAccount(a) }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            .padding(.horizontal, 12).frame(height: 44).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func socialField(_ label: String, _ icon: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(Color(hex: "6ea300"))
                Text("@").foregroundColor(Brand.soft)
                TextField("usuario", text: binding).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 12).frame(height: 44).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var minBirth: Date { Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date() }
    private var birthLabel: String {
        guard let b = store.profile.birthdate else { return "Elegir fecha" }
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateStyle = .long
        return f.string(from: b)
    }

    private func field(_ label: String, binding: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            TextField(label, text: binding)
                .keyboardType(keyboard)
                .padding(.horizontal, 12).frame(height: 44)
                .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Ajustes de la app

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fxSound") private var soundOn = true
    @AppStorage("fxHaptics") private var hapticsOn = true
    @ObservedObject private var health = HealthManager.shared
    @State private var confirmLogout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PanelCard {
                        Text("CUENTA").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        NavigationLink { EditProfileView().environmentObject(store) } label: {
                            settingsRow("Editar perfil", "person.crop.circle", chevron: true)
                        }.buttonStyle(.plain)
                        Divider()
                        Toggle(isOn: Binding(get: { store.profile.isPrivate }, set: { store.profile.isPrivate = $0; store.persist() })) {
                            Label("Cuenta privada", systemImage: "lock.fill")
                        }.tint(Brand.green)
                        Text("Si tu cuenta es privada, quien quiera seguirte tendrá que enviarte una solicitud.")
                            .font(.caption2).foregroundColor(Brand.soft)
                    }

                    PanelCard {
                        Text("PREFERENCIAS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        Toggle(isOn: $soundOn) { Label("Sonidos", systemImage: "speaker.wave.2.fill") }.tint(Brand.green)
                        Toggle(isOn: $hapticsOn) { Label("Vibración", systemImage: "iphone.radiowaves.left.and.right") }.tint(Brand.green)
                        Divider()
                        HStack { Label("Idioma", systemImage: "globe"); Spacer(); Text("Español").foregroundColor(Brand.soft) }
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                    }

                    if health.isAvailable {
                        PanelCard {
                            Text("SALUD").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                            if health.connected {
                                HStack(spacing: 8) {
                                    Image(systemName: "heart.fill").foregroundColor(Brand.red)
                                    Text("Conectado con Salud").font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink)
                                    Spacer()
                                    Image(systemName: "checkmark.seal.fill").foregroundColor(Color(hex: "4b8a1f"))
                                }
                            } else {
                                Text("Conecta la app Salud para registrar tu frecuencia cardíaca en los entrenos.")
                                    .font(.footnote).foregroundColor(Brand.muted)
                                Button { FX.tap(); Task { await health.connect() } } label: {
                                    Label("Conectar con Salud", systemImage: "heart.fill")
                                }.buttonStyle(PrimaryButtonStyle())
                            }
                        }
                    }

                    PanelCard {
                        Text("LEGAL Y SOPORTE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        NavigationLink { LegalView(kind: .privacy) } label: { settingsRow("Política de privacidad", "hand.raised.fill", chevron: true) }.buttonStyle(.plain)
                        Divider()
                        NavigationLink { LegalView(kind: .terms) } label: { settingsRow("Términos de uso", "doc.text.fill", chevron: true) }.buttonStyle(.plain)
                        Divider()
                        if let url = URL(string: "mailto:soporte@forgeloop.app") {
                            Link(destination: url) { settingsRow("Soporte", "questionmark.circle.fill", chevron: true) }
                        }
                        Divider()
                        HStack { Label("Versión", systemImage: "info.circle"); Spacer(); Text("1.0").foregroundColor(Brand.soft) }
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                    }

                    Button(role: .destructive) { confirmLogout = true } label: {
                        Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .background(Brand.bg)
            .navigationTitle("Ajustes").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) { FX.warning(); store.logout(); dismiss() }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("Volverás a la pantalla de creación de cuenta.") }
        }
    }

    private func settingsRow(_ title: String, _ icon: String, chevron: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
            Spacer()
            if chevron { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft) }
        }
    }
}

// MARK: - Legal

enum LegalKind { case privacy, terms }

struct LegalView: View {
    let kind: LegalKind

    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(size: 14)).foregroundColor(Color(hex: "2c3127"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(Brand.bg)
        .navigationTitle(kind == .privacy ? "Política de privacidad" : "Términos de uso")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: String {
        switch kind {
        case .privacy:
            return """
            En Forge Loop nos tomamos en serio tu privacidad.

            Datos que tratamos
            • Tu cuenta (nombre, @usuario y foto), tus datos de perfil (sexo, edad, país, ciudad, gimnasio) y tus entrenos.
            • Si conectas la app Salud, leemos tu frecuencia cardíaca solo durante el entrenamiento para mostrarla y guardarla en la sesión.
            • Si concedes permiso de ubicación, la usamos para el ranking y para mostrarte gente cercana; nunca compartimos tu posición exacta.

            Dónde se guardan
            • Actualmente tus datos se almacenan en tu dispositivo. No se venden ni se ceden a terceros con fines publicitarios.

            Tus derechos
            • Puedes editar o borrar tus datos en cualquier momento desde tu perfil, y cerrar sesión para eliminar tu cuenta local.

            Contacto
            • Para cualquier duda escríbenos a soporte@forgeloop.app.

            Esta política puede actualizarse; te avisaremos de cambios relevantes dentro de la app.
            """
        case .terms:
            return """
            Términos de uso de Forge Loop.

            Uso de la app
            • Forge Loop te ayuda a registrar tus entrenamientos y conectar con otras personas. Eres responsable de la información que publicas.

            Salud y seguridad
            • El contenido de la app es informativo y no sustituye el consejo de un profesional. Entrena de forma segura y consulta a un médico antes de empezar un programa.

            Comunidad
            • Trata con respeto al resto de usuarios. Nos reservamos el derecho de retirar contenido o cuentas que incumplan estas normas.

            Responsabilidad
            • La app se ofrece "tal cual". En la medida que permita la ley, no nos hacemos responsables de daños derivados del uso de la app.

            Contacto
            • soporte@forgeloop.app
            """
        }
    }
}

struct MenuField: View {
    let label: String
    let placeholder: String
    let selected: String
    let options: [(display: String, value: String)]
    var onSelect: (String) -> Void

    private var currentDisplay: String? { options.first { $0.value == selected }?.display }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Menu {
                ForEach(options, id: \.value) { opt in
                    Button { onSelect(opt.value) } label: {
                        if opt.value == selected { Label(opt.display, systemImage: "checkmark") } else { Text(opt.display) }
                    }
                }
            } label: {
                HStack {
                    Text(currentDisplay ?? placeholder)
                        .foregroundColor(currentDisplay == nil ? Brand.soft : Brand.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundColor(Brand.soft)
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 12).frame(height: 44)
                .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
