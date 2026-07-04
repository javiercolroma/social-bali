import SwiftUI

/// Chat con Forgey (IA on-device). UN punto central, accesible desde la cabecera de
/// TODAS las pantallas: le preguntas lo que quieras sobre tu entrenamiento y responde
/// la mascota con tus datos reales. Nada sale del dispositivo.
struct ForgeyChatView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatLine] = []
    @State private var draft = ""
    @State private var thinking = false
    @FocusState private var focused: Bool

    struct ChatLine: Identifiable { let id = UUID(); let fromMe: Bool; let text: String }

    private let suggestions = [
        "¿Qué debería entrenar hoy?",
        "¿En qué ejercicios progreso menos?",
        "¿En qué crees que debo mejorar?",
        "¿Cómo va mi constancia este mes?",
    ]
    private var unavailable: String? { ForgeyAI.unavailableReason() }

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
                        TextField("Pregúntale a Forgey…", text: $draft)
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
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() }.foregroundColor(Brand.soft) } }
            .navigationBarTitleDisplayMode(.inline)
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
                            Text(s).font(.system(size: 14, weight: .heavy)).foregroundColor(Brand.ink)
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
                Text(m.text).font(.system(size: 15)).foregroundColor(Color(hex: "10150a"))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Brand.greenSoft).clipShape(RoundedRectangle(cornerRadius: 15))
            } else {
                Mascot(size: 26).offset(y: 2)
                Text(m.text).font(.system(size: 15)).foregroundColor(Color(hex: "2c3127"))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Brand.line))
                Spacer(minLength: 40)
            }
        }
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

    private func send() {
        let q = draft.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !thinking else { return }
        FX.tap()
        messages.append(ChatLine(fromMe: true, text: q))
        draft = ""; thinking = true
        Task {
            do {
                let answer = try await ForgeyAI.shared.ask(q, store: store)
                messages.append(ChatLine(fromMe: false, text: answer))
            } catch {
                messages.append(ChatLine(fromMe: false, text: "Ups, no he podido pensar la respuesta 😅 \(error.localizedDescription)"))
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
    @State private var descriptionText = ""
    @State private var generated: WorkoutTemplate?
    @State private var generating = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private let examples = [
        "Pecho y tríceps, 45 minutos, nivel intermedio",
        "Pierna completa con énfasis en glúteo",
        "Full body rápido para un día flojo",
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
                            Text(generating ? "Creando…" : (generated == nil ? "Crear entreno" : "Regenerar"))
                        }.frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(enabled: !descriptionText.isEmpty && !generating))
                    .disabled(descriptionText.isEmpty || generating)

                    if let w = generated {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(w.name).font(.system(size: 17, weight: .heavy)).foregroundColor(Brand.ink)
                                    Text("\(w.exercises.count) ejercicios · \(w.block)").font(.caption).foregroundColor(Brand.muted)
                                }
                                Spacer()
                            }
                            WorkoutExerciseList(exercises: w.exercises)
                            Button {
                                FX.success()
                                store.addWorkout(name: w.name, group: w.block, exercises: w.exercises)
                                dismiss()
                            } label: { Label("Guardar en mi plan", systemImage: "checkmark").frame(maxWidth: .infinity) }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Crear con Forgey").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() }.foregroundColor(Brand.soft) } }
        }
    }

    private func generate() {
        guard !generating else { return }
        error = nil; generating = true; FX.tap()
        Task {
            do { generated = try await ForgeyAI.shared.generateWorkout(from: descriptionText, store: store); FX.success() }
            catch { self.error = error.localizedDescription }
            generating = false
        }
    }
}
