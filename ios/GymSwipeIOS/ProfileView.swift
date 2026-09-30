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
                    field("Name", binding: accountName)
                    handleField
                }

                clubSection

                PanelCard { ActivityPhotosEditor() }

                PanelCard {
                    Text("DETAILS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    // Guarda el CÓDIGO (`man`), no la etiqueta: ver Gender en SocialClub.swift.
                    MenuField(label: "Gender", placeholder: "Choose",
                              selected: Gender.from(store.profile.sex)?.rawValue ?? "",
                              options: Gender.allCases.map { ($0.label, $0.rawValue) }) {
                        store.profile.sex = $0; store.persist()
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DATE OF BIRTH").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        Button { birthSelection = store.profile.birthdate ?? birthSelection; showBirthPicker = true } label: {
                            HStack {
                                Text(birthLabel).foregroundColor(store.profile.birthdate == nil ? Brand.soft : Brand.ink)
                                Spacer()
                                if !ageText.isEmpty { Text("\(ageText) years").font(.caption).fontWeight(.heavy).foregroundColor(Color(hex: "4b6211")) }
                                Image(systemName: "calendar").font(.caption).foregroundColor(Brand.soft)
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 12).frame(height: 44).background(Brand.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    CountryField(label: "Country", selected: store.profile.country) { store.profile.country = $0; store.persist() }
                    CitySearchField(label: "City", selected: store.profile.city, country: store.profile.country) { store.profile.city = $0; store.persist() }
                    field("Area / neighbourhood (optional)", binding: Binding(get: { store.profile.region ?? "" }, set: { store.profile.region = $0; store.persist() }))
                    field("Gym", binding: Binding(get: { store.profile.gym }, set: { store.profile.gym = $0; store.persist() }))
                }

                PanelCard {
                    Text("SOCIAL MEDIA").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                    socialField("Instagram", "camera.circle.fill", Binding(get: { store.profile.instagram ?? "" }, set: { store.profile.instagram = clean($0); store.persist() }))
                    socialField("TikTok", "music.note", Binding(get: { store.profile.tiktok ?? "" }, set: { store.profile.tiktok = clean($0); store.persist() }))
                    socialField("X (Twitter)", "at", Binding(get: { store.profile.twitter ?? "" }, set: { store.profile.twitter = clean($0); store.persist() }))
                    Text("They'll show up as cards on your profile that link straight to your accounts.")
                        .font(.caption2).foregroundColor(Brand.soft)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Brand.bg)
        .navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
        .onDisappear { store.syncProfileToBackend() }
        .sheet(isPresented: $showEditor) {
            if let d = editingData { PhotoEditorView(data: d).environmentObject(store) }
        }
        .sheet(isPresented: $showBirthPicker) {
            NavigationStack {
                VStack {
                    DatePicker("Date of birth", selection: $birthSelection, in: minBirth...Date(), displayedComponents: .date)
                        .datePickerStyle(.wheel).labelsHidden().padding()
                    Spacer()
                }
                .background(Brand.bg)
                .navigationTitle("Date of birth").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showBirthPicker = false } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { store.profile.birthdate = birthSelection; store.persist(); showBirthPicker = false }.fontWeight(.heavy)
                    }
                }
            }
            .presentationDetents([.height(360)])
        }
    }

    // MARK: Club (bio, deportes, barrio, estancia, de dónde eres, intenciones)

    /// Lo mismo que pide el onboarding, editable después. Sin esto, quien ya tenía
    /// cuenta antes de la Fase 1 no podía rellenar su identidad nunca.
    private var clubSection: some View {
        PanelCard {
            Text("YOUR CLUB PROFILE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.t("Bio").uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                TextField("Sunrise surf → coffee → work.", text: bioBinding, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                Text("\((store.profile.bio ?? "").count)/140").font(.caption2).foregroundColor(Brand.soft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("SPORTS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                WrapLayout(spacing: 6) {
                    ForEach(Sport.curated) { s in
                        toggleChip("\(s.emoji) \(s.label)", on: store.profile.sportList.contains(s)) { toggleSport(s) }
                    }
                }
            }

            MenuField(label: "Where in Bali", placeholder: "Choose",
                      selected: store.profile.neighborhood ?? "",
                      options: Neighborhood.allCases.map { ($0.label, $0.rawValue) }) {
                store.profile.neighborhood = $0; store.persist()
            }

            MenuField(label: "How long are you around?", placeholder: "Choose",
                      selected: store.profile.stayKind ?? "",
                      options: StayKind.allCases.map { ($0.label, $0.rawValue) }) { raw in
                store.profile.stayKind = raw
                if raw == StayKind.until.rawValue {
                    // Fecha por defecto razonable: sin ella «Leaving on a date» no dice nada.
                    if store.profile.stayUntil == nil { store.profile.stayUntil = Calendar.current.date(byAdding: .month, value: 1, to: Date()) }
                } else {
                    store.profile.stayUntil = nil
                }
                store.persist()
            }
            if store.profile.stayKind == StayKind.until.rawValue {
                DatePicker("Leaving on", selection: stayUntilBinding, in: Date()..., displayedComponents: .date)
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
            }

            CountryField(label: L10n.t("Where are you from?"), selected: store.profile.homeCountry ?? "") {
                store.profile.homeCountry = $0; store.persist()
            }
            CitySearchField(label: L10n.t("Home city"), selected: store.profile.homeCity ?? "", country: store.profile.homeCountry ?? "") {
                store.profile.homeCity = $0; store.persist()
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("OPEN TO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                WrapLayout(spacing: 6) {
                    ForEach(ConnectionIntent.allCases) { i in
                        let locked = i == .dating && !store.profile.canDate
                        toggleChip(i.label, icon: locked ? "lock.fill" : i.icon, on: store.profile.intentList.contains(i)) { toggleIntent(i) }
                            .disabled(locked).opacity(locked ? 0.5 : 1)
                    }
                }
                if !store.profile.canDate {
                    if store.profile.birthdate == nil {
                        Button { birthSelection = store.profile.birthdate ?? birthSelection; showBirthPicker = true } label: {
                            Text("Dating is for members 18 and over. Add your date of birth to turn it on.")
                                .font(.caption).foregroundColor(Color(hex: "4b6211")).multilineTextAlignment(.leading)
                        }.buttonStyle(.plain)
                    } else {
                        Text("Dating is for members 18 and over.").font(.caption).foregroundColor(Brand.soft)
                    }
                }
            }
        }
    }

    private var bioBinding: Binding<String> {
        Binding(get: { store.profile.bio ?? "" },
                set: { v in
                    let t = String(v.prefix(140))
                    store.profile.bio = t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : t
                    store.persist()
                })
    }

    private var stayUntilBinding: Binding<Date> {
        Binding(get: { store.profile.stayUntil ?? Date() },
                set: { store.profile.stayUntil = $0; store.persist() })
    }

    /// Mantiene el orden curado (igual que el onboarding): la tarjeta se ve estable.
    private func toggleSport(_ s: Sport) {
        FX.selection()
        var set = Set(store.profile.sportList)
        if set.contains(s) { set.remove(s) } else { set.insert(s) }
        store.profile.sportList = Sport.curated.filter(set.contains)
        store.persist()
    }

    private func toggleIntent(_ i: ConnectionIntent) {
        FX.selection()
        var set = Set(store.profile.intentList)
        if set.contains(i) { set.remove(i) } else { set.insert(i) }
        store.profile.intentList = ConnectionIntent.allCases.filter(set.contains)
        store.persist()
    }

    private func toggleChip(_ text: String, icon: String? = nil, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon) }
                Text(text)
            }
            .font(.system(size: 13, weight: .heavy))
            .foregroundColor(on ? Color(hex: "10150a") : Brand.ink)
            .padding(.horizontal, 11).frame(height: 32)
            .background(on ? Brand.green : Brand.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(on ? Color.clear : Brand.line))
        }.buttonStyle(.plain)
    }

    private func clean(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
        return t.isEmpty ? nil : t
    }

    private var accountName: Binding<String> {
        Binding(get: { store.account?.name ?? "" },
                set: { var a = store.account ?? Account(name: "", handle: ""); a.name = $0; store.saveAccount(a) })
    }

    @State private var editedHandle: String = ""
    @State private var handleAvailability: Bool? = nil
    @State private var handleCheckTask: Task<Void, Never>?

    /// El @usuario ya NO se guarda a cada tecla: se comprueba la disponibilidad REAL en el
    /// servidor (debounce) y solo se aplica si está libre (o es el tuyo actual).
    private var handleField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("USERNAME").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            HStack(spacing: 2) {
                Text("@").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.soft)
                TextField("your_username", text: $editedHandle)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: editedHandle) { v in
                        let h = normalizeHandle(v)
                        if h != v { editedHandle = h; return }
                        scheduleHandleCheck(h)
                    }
            }
            .padding(.horizontal, 12).frame(height: 44).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
            if !editedHandle.isEmpty, editedHandle != (store.account?.handle ?? "") {
                if handleAvailability == false {
                    Text("That @username is taken").font(.caption).foregroundColor(Color(hex: "c14b46"))
                } else if handleAvailability == true {
                    Text("Available ✓ saved").font(.caption).foregroundColor(Color(hex: "4b8a1f"))
                } else if BackendConfig.isConfigured {
                    Text("Checking availability…").font(.caption).foregroundColor(Brand.soft)
                }
            }
        }
        .onAppear { if editedHandle.isEmpty { editedHandle = store.account?.handle ?? "" } }
    }

    private func scheduleHandleCheck(_ h: String) {
        handleCheckTask?.cancel()
        handleAvailability = nil
        guard h != (store.account?.handle ?? "") else { return }
        guard BackendConfig.isConfigured else {
            // Sin backend: guarda directo (modo local).
            var a = store.account ?? Account(name: "", handle: ""); a.handle = h; store.saveAccount(a)
            return
        }
        guard !h.isEmpty else { return }
        handleCheckTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            let ok = await Backend.shared.isHandleAvailable(h)
            if Task.isCancelled { return }
            handleAvailability = ok
            if ok == true {
                var a = store.account ?? Account(name: "", handle: ""); a.handle = h; store.saveAccount(a)
            }
        }
    }

    private func socialField(_ label: String, _ icon: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(Color(hex: "6ea300"))
                Text("@").foregroundColor(Brand.soft)
                TextField("username", text: binding).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 12).frame(height: 44).background(Brand.surface).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var minBirth: Date { Calendar.current.date(byAdding: .year, value: -100, to: Date()) ?? Date() }
    private var birthLabel: String {
        guard let b = store.profile.birthdate else { return "Choose date" }
        let f = DateFormatter(); f.locale = L10n.locale; f.dateStyle = .long
        return f.string(from: b)
    }

    private func field(_ label: String, binding: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.t(label).uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            TextField(L10n.t(label), text: binding)
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
    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteFailed = false
    @State private var toursReset = false
    @State private var showDistance = true
    @State private var showOnline = true

    private func savePresenceVisibility() {
        FX.tap()
        let d = showDistance, o = showOnline
        Task { await Backend.shared.setPresenceVisibility(showDistance: d, showOnline: o) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    PanelCard {
                        Text("ACCOUNT").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        NavigationLink { EditProfileView().environmentObject(store) } label: {
                            settingsRow("Edit profile", "person.crop.circle", chevron: true)
                        }.buttonStyle(.plain)
                        Divider()
                        Toggle(isOn: Binding(get: { store.profile.isPrivate }, set: { store.profile.isPrivate = $0; store.persist() })) {
                            Label("Private account", systemImage: "lock.fill")
                        }.tint(Brand.green)
                        Text("If your account is private, anyone who wants to follow you will have to send you a request.")
                            .font(.caption2).foregroundColor(Brand.soft)
                    }

                    // Your Circle (0028): cada persona decide si enseña su distancia y su online.
                    PanelCard {
                        Text("YOUR CIRCLE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        Toggle(isOn: Binding(get: { showDistance }, set: { showDistance = $0; savePresenceVisibility() })) {
                            Label("Show my distance", systemImage: "location.fill")
                        }.tint(Brand.green)
                        Toggle(isOn: Binding(get: { showOnline }, set: { showOnline = $0; savePresenceVisibility() })) {
                            Label("Show when I'm online", systemImage: "circle.fill")
                        }.tint(Brand.green)
                        Text("Others only see how far away you are, never where you are.")
                            .font(.caption2).foregroundColor(Brand.soft)
                    }
                    .task {
                        if let v = await Backend.shared.fetchPresenceVisibility() {
                            showDistance = v.showDistance; showOnline = v.showOnline
                        }
                    }

                    PanelCard {
                        Text("PREFERENCES").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        Toggle(isOn: $soundOn) { Label("Sounds", systemImage: "speaker.wave.2.fill") }.tint(Brand.green)
                        Toggle(isOn: $hapticsOn) { Label("Haptics", systemImage: "iphone.radiowaves.left.and.right") }.tint(Brand.green)
                    }

                    PanelCard {
                        Text("LEGAL & SUPPORT").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                        NavigationLink { LegalView(kind: .privacy) } label: { settingsRow("Privacy policy", "hand.raised.fill", chevron: true) }.buttonStyle(.plain)
                        Divider()
                        NavigationLink { LegalView(kind: .terms) } label: { settingsRow("Terms of use", "doc.text.fill", chevron: true) }.buttonStyle(.plain)
                        Divider()
                        NavigationLink { LegalView(kind: .community) } label: { settingsRow("Community guidelines", "person.2.fill", chevron: true) }.buttonStyle(.plain)
                        Divider()
                        if let url = URL(string: "mailto:soporte@forgeloop.app") {
                            Link(destination: url) { settingsRow("Support", "questionmark.circle.fill", chevron: true) }
                        }
                        Divider()
                        Button { FX.tap(); store.resetTours(); toursReset = true } label: {
                            settingsRow("Replay tutorials", "sparkles", chevron: false)
                        }.buttonStyle(.plain)
                        Divider()
                        HStack { Label("Version", systemImage: "info.circle"); Spacer(); Text("1.0").foregroundColor(Brand.soft) }
                            .font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                    }

                    Button(role: .destructive) { confirmLogout = true } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Brand.redSoft).clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Eliminación de cuenta in-app (obligatoria para App Store, guideline 5.1.1).
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Text("Delete account").font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "a73232"))
                            .frame(maxWidth: .infinity)
                    }.padding(.top, 2)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .background(Brand.bg)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .alert("Tutorials turned back on", isPresented: $toursReset) {
                Button("Got it", role: .cancel) {}
            } message: {
                Text("Forgey will guide you again the next time you open each section.")
            }
            .confirmationDialog("Sign out?", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { FX.warning(); store.logout(); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("You'll go back to the sign-up screen.") }
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete permanently", role: .destructive) {
                    deleting = true
                    Task {
                        let ok = await store.deleteAccount()
                        deleting = false
                        if ok { FX.warning(); dismiss() } else { deleteFailed = true }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your profile, workouts, messages, followers and photos will be deleted FOREVER. This can't be undone.")
            }
            .alert("Couldn't delete the account", isPresented: $deleteFailed) {
                Button("Got it", role: .cancel) {}
            } message: { Text("Check your connection and try again.") }
            .overlay { if deleting { ZStack { Color.black.opacity(0.25).ignoresSafeArea(); ProgressView().tint(.white) } } }
        }
    }

    private func settingsRow(_ title: String, _ icon: String, chevron: Bool) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
            Spacer()
            if chevron { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.soft) }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Legal

enum LegalKind { case privacy, terms, community }

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
        .navigationTitle(kind == .privacy ? "Privacy policy" : (kind == .community ? "Community guidelines" : "Terms of use"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: String {
        switch kind {
        case .privacy:
            return """
            At Bali Circle we take your privacy seriously.

            Data we process
            • Your account (name, @username and photo), your profile details (sex, age, country, city, gym) and your workouts.
            • If you connect the Health app, we read your heart rate only during a workout, to show it and save it with the session.
            • If you grant location permission, we use it for the ranking and to show you people nearby; we never share your exact position.

            Where it is stored
            • Your data is currently stored on your device. It is not sold or passed on to third parties for advertising.

            Your rights
            • You can edit or delete your data at any time from your profile, and sign out to remove your local account.

            Contact
            • For any questions, write to us at soporte@forgeloop.app.

            This policy may be updated; we will let you know about relevant changes inside the app.
            """
        case .terms:
            return """
            Bali Circle Terms of Use.

            Using the app
            • Bali Circle helps you log your workouts and connect with other people. You are responsible for the information you post.

            Health and safety
            • The content in the app is for information only and does not replace advice from a professional. Train safely and see a doctor before starting a programme.

            Community and user content
            • Treat other users with respect. We apply ZERO TOLERANCE to objectionable content and abusive behaviour.
            • It is forbidden to post illegal content, harassment, hate speech, threats, nudity or sexual content, violence, spam, impersonation or any material that infringes the rights of others.
            • You can REPORT any post or user (⋯ menu) and BLOCK anyone you don't want to see. We review reports and remove infringing content and abusive users within 24 hours at most. Content with multiple reports is hidden automatically.
            • See the "Community guidelines" for details. We reserve the right to remove content or accounts that break them.

            Liability
            • The app is provided "as is". To the extent permitted by law, we are not liable for damages arising from the use of the app.

            Contact
            • soporte@forgeloop.app
            """
        case .community:
            return """
            Bali Circle Community Guidelines.

            We want a safe, motivating community. By using the app you accept these guidelines. We apply ZERO TOLERANCE to objectionable content and abusive users.

            FORBIDDEN content
            • Harassment, bullying or threats towards other people.
            • Hate speech or discrimination based on race, ethnicity, religion, sex, orientation, disability, etc.
            • Nudity, sexual or sexually suggestive content.
            • Violence, self-harm or content that promotes eating disorders or dangerous substances.
            • Illegal content, spam, scams or impersonation.
            • Material that infringes copyright or the rights of others.

            How we keep the community safe
            • REPORT: on any post or profile, open the ⋯ menu and tap "Report".
            • BLOCK: from the same menu you can block a user; you will stop seeing their content and they will stop seeing yours.
            • MODERATION: we review reports, remove infringing content and ban abusive users within 24 hours at most. Content with several reports is hidden automatically while it is reviewed.

            Consequences
            • Breaking these guidelines may lead to removal of content, limited features or deletion of the account.

            Report a problem or appeal
            • Write to us at soporte@forgeloop.app.
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
            Text(L10n.t(label).uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Menu {
                ForEach(options, id: \.value) { opt in
                    Button { onSelect(opt.value) } label: {
                        if opt.value == selected { Label(opt.display, systemImage: "checkmark") } else { Text(opt.display) }
                    }
                }
            } label: {
                HStack {
                    Text(currentDisplay ?? L10n.t(placeholder))
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
