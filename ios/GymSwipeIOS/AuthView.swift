import SwiftUI
import AuthenticationServices
import GoogleSignIn

/// Pantalla de bienvenida / inicio de sesión: tres vías consistentes (Apple, Google,
/// email). El email abre una hoja dedicada (`EmailAuthSheet`) con modo explícito
/// Iniciar sesión / Crear cuenta. Sin backend: la identidad se guarda en local.
struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @State private var showEmail = false
    @State private var googleNote = false
    @State private var appleNonce = ""   // nonce en crudo para el login Apple → Supabase

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                ZStack {
                    Circle().fill(Brand.greenSoft).frame(width: 104, height: 104)
                    Image(systemName: "dumbbell.fill").font(.system(size: 44, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                }
                Text("Forge Loop").font(.system(size: 30, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Entra para guardar tus entrenos y tu progreso.")
                    .font(.subheadline).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()

                // Tres botones de la misma familia (misma altura y radio): se lee profesional.
                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { req in
                        let nonce = AuthNonce.random()
                        appleNonce = nonce
                        req.requestedScopes = [.fullName, .email]
                        req.nonce = AuthNonce.sha256(nonce)   // Apple recibe el hash; Supabase, el crudo
                    } onCompletion: { result in
                        handleApple(result)
                    }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52).clipShape(RoundedRectangle(cornerRadius: 14))

                    providerButton(icon: "globe", label: "Continuar con Google") { handleGoogle() }
                    providerButton(icon: "envelope.fill", label: "Continuar con email") { FX.tap(); showEmail = true }
                }

                Text("Al continuar aceptas los términos y la política de privacidad.")
                    .font(.caption2).foregroundColor(Brand.soft).multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(24)
        }
        .sheet(isPresented: $showEmail) { EmailAuthSheet().environmentObject(store) }
        .alert("Falta configurar Google", isPresented: $googleNote) {
            Button("Vale", role: .cancel) {}
        } message: {
            Text("Para activar Google hay que crear un OAuth Client ID de iOS en Google Cloud y pegarlo en AuthConfig.swift (instrucciones dentro). Mientras, entra con Apple o email.")
        }
    }

    /// Botón de proveedor (blanco, borde fino) — mismo tamaño que el de Apple.
    private func providerButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold))
                Text(label).font(.system(size: 16, weight: .heavy))
            }
            .foregroundColor(Brand.ink).frame(maxWidth: .infinity).frame(height: 52)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
        }
    }

    /// Inicia sesión con Google (SDK oficial). Si aún no hay client ID configurado,
    /// muestra la ayuda en vez de fallar. Sin backend todavía: guardamos la identidad
    /// del proveedor en local (`store.signIn`) y el onboarding monta el perfil.
    private func handleGoogle() {
        FX.tap()
        guard GoogleAuth.isConfigured else { googleNote = true; return }
        guard let root = UIApplication.shared.activeRootViewController else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: GoogleAuth.clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: root) { result, error in
            guard error == nil, let user = result?.user else { return }
            let profile = user.profile
            let uid = user.userID ?? profile?.email ?? UUID().uuidString
            FX.success(sound: true)
            withAnimation { store.signIn(provider: "google", userId: uid, email: profile?.email, name: profile?.name) }
            // Best-effort: si hay backend configurado, abre también la sesión en Supabase.
            if Backend.shared.isConfigured, let idToken = user.idToken?.tokenString {
                Task {
                    do { let uid = try await Backend.shared.signInWithGoogle(idToken: idToken)
                         print("[Backend] sesión Supabase (Google) abierta: \(uid)")
                         store.hydrateAccountFromBackend(); store.syncSessionsFromBackend() }
                    catch { print("[Backend] Google → Supabase falló:", error); store.checkingProfile = false }
                }
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let c = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let name = [c.fullName?.givenName, c.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        FX.success(sound: true)
        withAnimation { store.signIn(provider: "apple", userId: c.user, email: c.email, name: name.isEmpty ? nil : name) }
        // Best-effort: si hay backend configurado, abre también la sesión en Supabase.
        if Backend.shared.isConfigured, let tokenData = c.identityToken,
           let idToken = String(data: tokenData, encoding: .utf8) {
            let nonce = appleNonce
            Task {
                do { let uid = try await Backend.shared.signInWithApple(idToken: idToken, nonce: nonce)
                     print("[Backend] sesión Supabase (Apple) abierta: \(uid)")
                     store.hydrateAccountFromBackend(); store.syncSessionsFromBackend() }
                catch { print("[Backend] Apple → Supabase falló:", error); store.checkingProfile = false }
            }
        }
    }
}

/// Hoja dedicada al email: modo EXPLÍCITO (Iniciar sesión / Crear cuenta), campos con
/// etiqueta, mostrar/ocultar contraseña y errores específicos por modo.
struct EmailAuthSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var creating = false
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var error: String?
    @State private var resetMsg: String?
    @State private var busy = false
    @FocusState private var focus: Field?
    private enum Field { case email, password }

    private var validEmail: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        return e.contains("@") && e.contains(".") && e.count >= 6
    }
    private var canSubmit: Bool { validEmail && password.count >= 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Título según el modo: siempre sabes si entras o te registras.
            VStack(alignment: .leading, spacing: 4) {
                Text(creating ? "Crea tu cuenta" : "¡Hola de nuevo!")
                    .font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                Text(creating ? "Regístrate con tu correo para guardar tu progreso."
                              : "Entra con el correo con el que te registraste.")
                    .font(.footnote).foregroundColor(Brand.muted)
            }
            .padding(.top, 22)

            HStack(spacing: 6) {
                modeTab("Iniciar sesión", isOn: !creating) { creating = false }
                modeTab("Crear cuenta", isOn: creating) { creating = true }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("CORREO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill").font(.system(size: 14)).foregroundColor(Brand.soft)
                    TextField("tu@email.com", text: $email)
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focus, equals: .email).submitLabel(.next)
                        .onSubmit { focus = .password }
                }
                .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(focus == .email ? Brand.green : Brand.line, lineWidth: focus == .email ? 1.5 : 1))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("CONTRASEÑA").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill").font(.system(size: 14)).foregroundColor(Brand.soft)
                    Group {
                        if showPassword {
                            TextField(creating ? "Mínimo 6 caracteres" : "Tu contraseña", text: $password)
                        } else {
                            SecureField(creating ? "Mínimo 6 caracteres" : "Tu contraseña", text: $password)
                        }
                    }
                    .textContentType(creating ? .newPassword : .password)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focus, equals: .password).submitLabel(.go)
                    .onSubmit { submit() }
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14)).foregroundColor(Brand.soft)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(focus == .password ? Brand.green : Brand.line, lineWidth: focus == .password ? 1.5 : 1))
            }

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption).foregroundColor(Color(hex: "a73232"))
            }
            if let resetMsg {
                Label(resetMsg, systemImage: "paperplane.fill")
                    .font(.caption).foregroundColor(Color(hex: "3f7d12"))
            }

            Button { submit() } label: {
                HStack(spacing: 8) {
                    if busy { ProgressView().tint(Color(hex: "10150a")) }
                    Text(busy ? (creating ? "Creando cuenta…" : "Entrando…")
                              : (creating ? "Crear cuenta" : "Entrar"))
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(enabled: canSubmit && !busy)).disabled(!canSubmit || busy)

            if !creating {
                Button { forgot() } label: {
                    Text("¿Olvidaste la contraseña?")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.soft)
                        .frame(maxWidth: .infinity)
                }.buttonStyle(.plain).disabled(!validEmail).opacity(validEmail ? 1 : 0.55)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Brand.bg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focus = .email } }
        .onChange(of: creating) { _ in error = nil; resetMsg = nil }
    }

    /// Pestaña del modo (mismo estilo que los selectores del resto de la app).
    private func modeTab(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button { FX.selection(); action() } label: {
            Text(label).font(.system(size: 14, weight: .heavy))
                .foregroundColor(isOn ? Color(hex: "10150a") : Brand.soft)
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(isOn ? Brand.green : Brand.chip)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func submit() {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard canSubmit, !busy else { return }
        error = nil; resetMsg = nil
        // Sin backend configurado: identidad local simple (como antes).
        guard Backend.shared.isConfigured else {
            FX.success(sound: true)
            dismiss()
            withAnimation { store.signIn(provider: "email", userId: e, email: e, name: nil) }
            return
        }
        busy = true
        Task {
            do {
                let uid = creating
                    ? try await Backend.shared.signUpEmail(e, password: password)
                    : try await Backend.shared.signInEmail(e, password: password)
                print("[Backend] sesión Supabase (email) abierta: \(uid)")
                FX.success(sound: true)
                dismiss()
                withAnimation { store.signIn(provider: "email", userId: uid.uuidString, email: e, name: nil) }
                store.hydrateAccountFromBackend(); store.syncSessionsFromBackend()
            } catch BackendError.emailTaken {
                error = "Ya existe una cuenta con este correo. Cambia a «Iniciar sesión»."
            } catch {
                print("[Backend] email → Supabase falló:", error)
                self.error = creating
                    ? "No pudimos crear la cuenta. Revisa el correo y usa una contraseña de 6+ caracteres."
                    : "Correo o contraseña incorrectos. ¿Eres nuevo? Elige «Crear cuenta»."
            }
            busy = false
        }
    }

    private func forgot() {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard validEmail, Backend.shared.isConfigured else { return }
        FX.tap()
        Task {
            do {
                try await Backend.shared.resetPassword(email: e)
                resetMsg = "Si el correo existe, te enviamos un enlace para restablecer la contraseña."
            } catch {
                resetMsg = "No pudimos enviar el correo. Inténtalo de nuevo."
            }
        }
    }
}
