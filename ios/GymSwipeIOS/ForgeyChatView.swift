import SwiftUI
import PhotosUI

/// Chat con Forgey (IA on-device). UN punto central, accesible desde la cabecera de
/// TODAS las pantallas: le preguntas lo que quieras sobre tu entrenamiento y responde
/// la mascota con tus datos reales. Nada sale del dispositivo.
struct ForgeyChatView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatLine] = []
    @State private var draft = ""
    @State private var thinking = false
    @State private var photoItem: PhotosPickerItem?
    @State private var genTopic: IdString?   // «Crear entreno de esto» → generador prellenado
    @State private var pendingPhoto: Data?           // foto a la espera de consentimiento
    @State private var showVisionConsent = false     // opt-in: la foto sale a la nube
    @FocusState private var focused: Bool

    struct ChatLine: Identifiable {
        let id = UUID()
        let fromMe: Bool
        let text: String
        var image: Data? = nil   // foto enviada (análisis de físico)
        /// Descripción de entreno escrita por el LLM (protocolo ENTRENO_SUGERIDO): si existe,
        /// se muestra «Crear entreno de esto» — SOLO cuando tiene sentido, ya redactada.
        var suggestion: String? = nil
    }

    private let suggestions = [
        "What should I train today?",
        "Which exercises am I progressing least on?",
        "What do you think I should improve?",
        "How's my consistency this month?",
    ]
    private var unavailable: String? { ForgeyEngine.unavailableReason() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            if let reason = unavailable {
                                unavailableCard(reason)
                            } else if messages.isEmpty {
                                emptyIntro
                            }
                            ForEach(messages) { bubble($0).id($0.id) }
                            // Botón SOLO cuando el modelo sugiere entreno (ENTRENO_SUGERIDO):
                            // la descripción viene YA escrita por el LLM con el contexto de la
                            // conversación — el usuario no tiene que teclear nada.
                            if !thinking, let last = messages.last, !last.fromMe, let sug = last.suggestion {
                                Button {
                                    FX.tap()
                                    genTopic = IdString(id: sug)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                        Text("Crear entreno de esto")
                                    }
                                    .font(.system(size: 13, weight: .heavy)).foregroundColor(Color(hex: "4b6211"))
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(Brand.greenSoft.opacity(0.4)).clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color(hex: "9ec85a")))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 34)
                            }
                            if thinking { thinkingBubble.id("thinking") }
                        }
                        .padding(14)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onChange(of: thinking) { t in if t { withAnimation { proxy.scrollTo("thinking", anchor: .bottom) } } }
                }

                if unavailable == nil {
                    HStack(spacing: 8) {
                        // Foto del físico → análisis por IA en la nube (con consentimiento).
                        // Solo si la visión-nube está activa (el modelo de Apple no ve imágenes).
                        if ForgeyEngine.cloudVisionAvailable {
                            PhotoPickerLabel(item: $photoItem, onPicked: { requestAnalyze($0) }) {
                                Image(systemName: "camera.fill").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                                    .frame(width: 46, height: 46).background(Brand.chip).clipShape(Circle())
                            }
                        }
                        TextField("Pregúntale a Forgey…", text: $draft, axis: .vertical)
                            .lineLimit(1...4)
                            // Tope de entrada: el modelo on-device es pequeño y las novelas lo marean.
                            .onChange(of: draft) { v in if v.count > 200 { draft = String(v.prefix(200)) } }
                            .focused($focused)
                            .padding(.horizontal, 16).frame(height: 46).background(Color.white).clipShape(Capsule())
                            .overlay(Capsule().stroke(Brand.line))
                            .submitLabel(.send).onSubmit { send() }
                        Button { send() } label: {
                            Image(systemName: "paperplane.fill").foregroundColor(Color(hex: "10150a"))
                                .frame(width: 46, height: 46).background(Brand.green).clipShape(Circle())
                        }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Brand.bg).overlay(Divider(), alignment: .top)
                }
            }
            .background(Brand.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } } }
        }
        // Opt-in la PRIMERA vez que se analiza una foto (la imagen sale del dispositivo).
        .alert("Analyse your physique", isPresented: $showVisionConsent) {
            Button("Cancelar", role: .cancel) { pendingPhoto = nil }
            Button("Continuar") {
                UserDefaults.standard.set(true, forKey: consentKey)
                if let d = pendingPhoto { analyzePhoto(d) }
                pendingPhoto = nil
            }
        } message: {
            Text("To analyse your physique, your photo is sent securely to our AI service. It is not stored or shared. Do you want to continue?")
        }
        // «Crear entreno de esto»: generador prellenado con el último consejo de Forgey.
        .sheet(item: $genTopic) { t in
            AIWorkoutSheet(initialDescription: t.id, autoGenerate: true).environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Mascot(size: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text("Forgey").font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill").font(.system(size: 9))
                    Text("Tu coach IA · todo se procesa en tu iPhone").font(.system(size: 11, weight: .semibold))
                }.foregroundColor(Brand.soft)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.bottom, 8)
        .overlay(Divider(), alignment: .bottom)
    }

    private var emptyIntro: some View {
        VStack(spacing: 12) {
            Text("¡Hola! Conozco tus entrenos y tu progreso.\n¿Qué quieres saber?")
                .font(.system(size: 14, weight: .semibold)).foregroundColor(Brand.muted)
                .multilineTextAlignment(.center).padding(.top, 16)
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Button { FX.tap(); draft = s; send() } label: {
                        HStack {
                            Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "4b6211"))
                            Text(LocalizedStringKey(s)).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                            Spacer()
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 16)).foregroundColor(Brand.green)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func unavailableCard(_ reason: String) -> some View {
        VStack(spacing: 10) {
            Mascot(size: 72)
            Text("Forgey IA no está disponible").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
            Text(reason).font(.footnote).foregroundColor(Brand.muted).multilineTextAlignment(.center)
            Text("Cuando esté activo, todo se procesa en tu dispositivo: tus datos no salen del iPhone.")
                .font(.caption2).foregroundColor(Brand.soft).multilineTextAlignment(.center)
        }
        .padding(18).frame(maxWidth: .infinity)
        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.line))
        .padding(.top, 20)
    }

    @ViewBuilder
    private func bubble(_ m: ChatLine) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if m.fromMe {
                Spacer(minLength: 40)
                VStack(alignment: .trailing, spacing: 6) {
                    if let img = m.image, let ui = UIImage(data: img) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: 150, height: 190).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Text(m.text).font(.system(size: 15)).foregroundColor(Color(hex: "10150a"))
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(Brand.greenSoft).clipShape(RoundedRectangle(cornerRadius: 15))
                }
            } else {
                Mascot(size: 26).offset(y: 2)
                pretty(m.text)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "2c3127"))
                    .lineSpacing(3.5)
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Brand.line))
                Spacer(minLength: 40)
            }
        }
    }

    /// Formato bonito de la respuesta: interpreta el Markdown inline línea a línea
    /// (las **negritas** se ven en negrita, no como asteriscos) y limpia viñetas «* » → «• ».
    private func pretty(_ text: String) -> Text {
        var out = Text("")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (i, raw) in lines.enumerated() {
            var line = String(raw)
            if line.hasPrefix("* ") || line.hasPrefix("- ") { line = "•  " + line.dropFirst(2) }
            let t: Text
            if let attr = try? AttributedString(markdown: line,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                t = Text(attr)
            } else {
                t = Text(line)
            }
            out = i == 0 ? t : out + Text("\n") + t
        }
        return out
    }

    private var thinkingBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Mascot(size: 26).offset(y: 2)
            HStack(spacing: 5) {
                ProgressView().scaleEffect(0.8)
                Text("Forgey está pensando…").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.soft)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Brand.line))
            Spacer(minLength: 40)
        }
    }

    /// Consentimiento POR USUARIO (no device-wide): si en el móvil hay varias cuentas, cada
    /// una debe dar su propio opt-in antes de que su foto salga a la nube.
    private var consentKey: String { "forgeCloudVisionConsent-\(store.auth?.userId ?? "anon")" }

    /// Pide consentimiento la primera vez (la foto sale del dispositivo); luego analiza.
    private func requestAnalyze(_ data: Data) {
        if UserDefaults.standard.bool(forKey: consentKey) {
            analyzePhoto(data)
        } else {
            pendingPhoto = data
            showVisionConsent = true
        }
    }

    /// Foto del físico: Claude la analiza en la nube y Forgey aconseja zonas a priorizar.
    private func analyzePhoto(_ data: Data) {
        guard !thinking else { return }
        FX.tap()
        messages.append(ChatLine(fromMe: true, text: "Which areas should I improve? 📷", image: data))
        thinking = true
        Task {
            do {
                let r = try await ForgeyEngine.analyzeBody(photo: data, store: store)
                messages.append(ChatLine(fromMe: false, text: r.text, suggestion: r.suggestion))
            } catch {
                messages.append(ChatLine(fromMe: false, text: "I couldn't analyse the photo 😅 \(error.localizedDescription)"))
            }
            thinking = false
        }
    }

    private func send() {
        let q = draft.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !thinking else { return }
        FX.tap()
        messages.append(ChatLine(fromMe: true, text: q))
        draft = ""; thinking = true
        Task {
            do {
                let r = try await ForgeyEngine.ask(q, store: store)
                messages.append(ChatLine(fromMe: false, text: r.text, suggestion: r.suggestion))
            } catch {
                messages.append(ChatLine(fromMe: false, text: "Oops, I couldn't come up with an answer 😅 \(error.localizedDescription)"))
            }
            thinking = false
        }
    }
}

// MARK: - Crear entreno con IA (Plan)

/// Describe el entreno que quieres y Forgey lo genera (on-device). Previsualizas
/// (con superseries y todo) y lo guardas en tu plan o lo regeneras.
struct AIWorkoutSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    /// Al «Guardar y entrenar»: además de guardar, se carga el entreno y se navega a Entreno.
    var onLoaded: () -> Void = {}
    /// Descripción prellenada (p. ej. desde el chip «Crear entreno de esto» del chat).
    var initialDescription: String = ""
    /// true → genera nada más abrirse (desde el chip del chat): el usuario aterriza
    /// directamente en la TARJETA del entreno, sin pasar por la pantalla de texto.
    var autoGenerate: Bool = false
    @State private var descriptionText = ""
    @State private var generated: WorkoutTemplate?
    @State private var generating = false
    @State private var error: String?
    @FocusState private var focused: Bool
    // Antes de guardar puedes ponerle el nombre que quieras y elegir grupo (existente o nuevo).
    @State private var editName = ""
    @State private var editGroup = ""
    @State private var adjusting = false   // abrir el editor completo con el entreno generado

    private let examples = [
        "Chest and triceps, 45 minutes, intermediate level",
        "Full leg day with a glute focus",
        "Quick full body for a low-energy day",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Mascot(size: 54)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Descríbeme tu entreno").font(.system(size: 18, weight: .heavy)).foregroundColor(Brand.ink)
                            Text("Lo genero en tu iPhone, con tu nivel en mente.").font(.caption).foregroundColor(Brand.muted)
                        }
                    }.padding(.top, 8)

                    TextField("P. ej. «Espalda y bíceps, 1 hora, que incluya dominadas»",
                              text: $descriptionText, axis: .vertical)
                        .lineLimit(3...5).focused($focused)
                        .onChange(of: descriptionText) { v in if v.count > 220 { descriptionText = String(v.prefix(220)) } }
                        .padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(focused ? Brand.green : Brand.line, lineWidth: focused ? 1.5 : 1))

                    if generated == nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("IDEAS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                            ForEach(examples, id: \.self) { e in
                                Button { descriptionText = e } label: {
                                    Text(e).font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "4b6211"))
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(Brand.greenSoft.opacity(0.35)).clipShape(Capsule())
                                }.buttonStyle(.plain)
                            }
                        }
                    }

                    if let error { Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundColor(Color(hex: "a73232")) }

                    Button { generate() } label: {
                        HStack(spacing: 8) {
                            if generating { ProgressView().tint(Color(hex: "10150a")) }
                            Image(systemName: "sparkles")
                            Text(generating ? "Creating…" : (generated == nil ? "Create workout" : "Regenerate"))
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: !descriptionText.isEmpty && !generating))
                    .disabled(descriptionText.isEmpty || generating)

                    if let w = generated {
                        VStack(alignment: .leading, spacing: 12) {
                            WorkoutExerciseList(exercises: w.exercises)

                            // Guárdalo con TU nombre y en el apartado que quieras (existente o nuevo).
                            VStack(alignment: .leading, spacing: 5) {
                                Text("NOMBRE").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                                TextField("Nombre del entreno", text: $editName)
                                    .font(.system(size: 15, weight: .heavy))
                                    .padding(.horizontal, 12).frame(height: 46).background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("GRUPO (apartado del plan)").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                                TextField("P. ej. Pierna, Push, Mis rutinas…", text: $editGroup)
                                    .padding(.horizontal, 12).frame(height: 46).background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.line))
                                // Tus apartados existentes, a un toque.
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(groupOptions, id: \.self) { g in
                                            Button { FX.tap(); editGroup = g } label: {
                                                Text(g).font(.system(size: 12, weight: .heavy))
                                                    .foregroundColor(editGroup == g ? Color(hex: "10150a") : Brand.muted)
                                                    .padding(.horizontal, 11).padding(.vertical, 6)
                                                    .background(editGroup == g ? Brand.green : Brand.chip)
                                                    .clipShape(Capsule())
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            // Guardar + CARGAR + ir a Entreno (lo natural si venías a entrenar).
                            Button {
                                FX.start()
                                let saved = save(w)
                                store.loadWorkout(saved)
                                dismiss()
                                onLoaded()
                            } label: { Label("Guardar y entrenar ahora", systemImage: "dumbbell.fill").frame(maxWidth: .infinity) }
                                .buttonStyle(PrimaryButtonStyle())

                            Button {
                                FX.success()
                                _ = save(w)
                                dismiss()
                            } label: {
                                Text("Solo guardar en el plan").font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                                    .frame(maxWidth: .infinity).frame(minHeight: 44)
                                    .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Para tocar series/reps/pesos o quitar ejercicios: editor completo.
                            Button { adjusting = true } label: {
                                Label("Ajustar ejercicios antes de guardar", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
                                    .frame(maxWidth: .infinity).frame(minHeight: 46)
                                    .background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Crear con Forgey").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetBackButton { dismiss() } } }
            // Desde el chip del chat: la descripción viene YA escrita por el LLM y se
            // genera SOLA — el usuario no teclea nada (aterriza en la tarjeta del entreno).
            .onAppear {
                if descriptionText.isEmpty { descriptionText = initialDescription }
                if autoGenerate && generated == nil && !generating { generate() }
            }
            // Editor completo prefijado con lo generado (nombre/grupo editados incluidos);
            // al guardar desde ahí se crea como entreno nuevo del plan.
            .sheet(isPresented: $adjusting, onDismiss: { dismiss() }) {
                if let w = generated {
                    CreateWorkoutView(editing: WorkoutTemplate(
                        id: w.id, name: editName.isEmpty ? w.name : editName,
                        description: w.description,
                        block: editGroup.isEmpty ? w.block : editGroup, exercises: w.exercises))
                        .environmentObject(store)
                }
            }
        }
    }

    /// Apartados existentes del plan + sugerencias típicas (sin duplicados).
    private var groupOptions: [String] {
        var seen = Set<String>(); var out: [String] = []
        for g in (store.customGroups + ["Legs", "Chest", "Back", "Push", "Pull", "Full body", "Others"]).map(L10n.x)
        where seen.insert(g).inserted { out.append(g) }
        return out
    }

    /// Guarda con el nombre/grupo elegidos (el `day` de los ejercicios pasa a ser el nombre
    /// final, para que el encabezado del entreno muestre lo que TÚ escribiste) y devuelve
    /// la plantilla lista para cargar.
    private func save(_ w: WorkoutTemplate) -> WorkoutTemplate {
        let finalName = editName.isEmpty ? w.name : editName
        let finalGroup = editGroup.isEmpty ? w.block : editGroup
        let exercises = w.exercises.map { e -> Exercise in var c = e; c.day = finalName; return c }
        store.addWorkout(name: finalName, group: finalGroup, exercises: exercises)
        return WorkoutTemplate(id: w.id, name: finalName, description: w.description,
                               block: finalGroup, exercises: exercises)
    }

    private func generate() {
        guard !generating else { return }
        error = nil; generating = true; FX.tap()
        Task {
            do {
                let w = try await ForgeyEngine.generateWorkout(from: descriptionText, store: store)
                generated = w; editName = L10n.x(w.name); editGroup = L10n.x(w.block)
                FX.success()
            }
            catch { self.error = error.localizedDescription }
            generating = false
        }
    }
}
