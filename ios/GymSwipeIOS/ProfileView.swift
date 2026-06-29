import SwiftUI
import UIKit
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var editingData: Data?
    @State private var showEditor = false
    @State private var showBirthPicker = false
    @State private var birthSelection = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @AppStorage("fxSound") private var soundOn = true
    @AppStorage("fxHaptics") private var hapticsOn = true
    @ObservedObject private var health = HealthManager.shared

    private var ageText: String {
        guard let b = store.profile.birthdate else { return "" }
        let years = Calendar.current.dateComponents([.year], from: b, to: Date()).year ?? 0
        return "\(years)"
    }

    var body: some View {
        let level = getLevelProgress(store.player.xp)
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    Menu {
                        Label("Español", systemImage: "checkmark")
                        Button { } label: { Text("English · próximamente") }.disabled(true)
                        Button { } label: { Text("Français · próximamente") }.disabled(true)
                    } label: {
                        HStack(spacing: 6) {
                            Text("🌐").font(.system(size: 16))
                            Text("ES").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.ink)
                            Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundColor(Brand.soft)
                        }
                        .padding(.horizontal, 12).frame(height: 38)
                        .background(Color.white).clipShape(Capsule())
                        .overlay(Capsule().stroke(Brand.line))
                    }
                }

                PanelCard {
                    HStack(spacing: 14) {
                        PhotoPickerLabel(item: $pickerItem, onPicked: { data in
                            var acc = store.account ?? Account(name: "", handle: "")
                            acc.photoData = data; acc.photoScale = 1; acc.photoOffsetX = 0; acc.photoOffsetY = 0
                            store.saveAccount(acc)
                            editingData = data; showEditor = true
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                MeAvatar(account: store.account, size: 64)
                                Image(systemName: "camera.fill").font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Brand.ink).padding(6).background(Brand.green).clipShape(Circle())
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.account?.name ?? "Tu perfil").font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
                            if let h = store.account?.handle { Text("@\(h)").font(.subheadline).foregroundColor(Brand.muted) }
                        }
                        Spacer()
                    }
                }

                PanelCard {
                    HStack {
                        Text("Nivel \(level.level)").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                        Spacer()
                        Text("\(store.player.xp) XP").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.muted)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Brand.chip)
                            Capsule().fill(Brand.green).frame(width: max(6, geo.size.width * level.progress))
                        }
                    }.frame(height: 10)
                    HStack(spacing: 18) {
                        metric("\(store.player.streak)", "Racha 🔥")
                        metric("\(store.gymScore.total)", "Gym Score")
                        metric("\(store.history.count)", "Registros")
                    }
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

                    CountryField(label: "País", selected: store.profile.country) {
                        store.profile.country = $0; store.persist()
                    }

                    CitySearchField(label: "Ciudad", selected: store.profile.city, country: store.profile.country) {
                        store.profile.city = $0; store.persist()
                    }

                    field("Zona / barrio (opcional)", binding: Binding(get: { store.profile.region ?? "" }, set: { store.profile.region = $0; store.persist() }))

                    field("Gimnasio", binding: Binding(get: { store.profile.gym }, set: { store.profile.gym = $0; store.persist() }))
                }

                PanelCard {
                    Text("AJUSTES").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    Toggle(isOn: $soundOn) { Label("Sonidos", systemImage: "speaker.wave.2.fill") }
                        .tint(Brand.green)
                    Toggle(isOn: $hapticsOn) { Label("Vibración", systemImage: "iphone.radiowaves.left.and.right") }
                        .tint(Brand.green)
                    Toggle(isOn: Binding(get: { store.profile.isPrivate }, set: { store.profile.isPrivate = $0; store.persist() })) {
                        Label("Cuenta privada", systemImage: "lock.fill")
                    }.tint(Brand.green)
                    Text("Si tu cuenta es privada, quien quiera seguirte tendrá que enviarte una solicitud que podrás aceptar o rechazar.")
                        .font(.caption2).foregroundColor(Brand.soft)
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
                            Text("Tu frecuencia cardíaca se registra durante el entrenamiento.")
                                .font(.caption).foregroundColor(Brand.muted)
                        } else {
                            Text("Conecta la app Salud para registrar tu frecuencia cardíaca en los entrenos.")
                                .font(.footnote).foregroundColor(Brand.muted)
                            Button { FX.tap(); Task { await health.connect() } } label: {
                                Label("Conectar con Salud", systemImage: "heart.fill")
                            }.buttonStyle(PrimaryButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Brand.bg)
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

    private var minBirth: Date { Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date() }
    private var birthLabel: String {
        guard let b = store.profile.birthdate else { return "Elegir fecha" }
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateStyle = .long
        return f.string(from: b)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(Brand.ink)
            Text(label).font(.caption2).fontWeight(.bold).foregroundColor(Brand.muted)
        }.frame(maxWidth: .infinity)
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
