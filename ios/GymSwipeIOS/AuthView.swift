import SwiftUI
import AuthenticationServices
import GoogleSignIn

/// Pantalla de inicio de sesión / registro. Sin backend todavía: la identidad del
/// proveedor se guarda localmente (`store.signIn`). Tras entrar, el onboarding monta el perfil.
struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @State private var showEmail = false
    @State private var email = ""
    @State private var password = ""
    @State private var emailError: String?
    @State private var resetMsg: String?
    @State private var emailBusy = false
    @State private var googleNote = false
    @State private var appleNonce = ""   // nonce en crudo para el login Apple → Supabase
    @FocusState private var emailFocused: Bool

    private var canEmail: Bool { validEmail && password.count >= 6 }

    private var validEmail: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        return e.contains("@") && e.contains(".") && e.count >= 6
    }

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

                    Button { handleGoogle() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe").font(.system(size: 17, weight: .bold))
                            Text("Continuar con Google").font(.system(size: 16, weight: .heavy))
                        }
                        .foregroundColor(Brand.ink).frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
                    }

                    if showEmail {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill").foregroundColor(Brand.soft)
                            TextField("tu@email.com", text: $email)
                                .keyboardType(.emailAddress).textInputAutocapitalization(.never)
                                .autocorrectionDisabled().focused($emailFocused).submitLabel(.next)
                        }
                        .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(emailFocused ? Brand.greenSoft : Brand.line, lineWidth: emailFocused ? 1.5 : 1))
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill").foregroundColor(Brand.soft)
                            SecureField("Contraseña (mín. 6)", text: $password)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .submitLabel(.go).onSubmit { signInEmail() }
                        }
                        .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
                        if let emailError {
                            Text(emailError).font(.caption).foregroundColor(Color(hex: "a73232"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button { signInEmail() } label: { Text(emailBusy ? "Entrando…" : "Continuar") }
                            .buttonStyle(PrimaryButtonStyle(enabled: canEmail && !emailBusy)).disabled(!canEmail || emailBusy)
                        Button { forgotPassword() } label: {
                            Text("¿Olvidaste la contraseña?").font(.system(size: 13, weight: .semibold)).foregroundColor(Brand.soft)
                        }.buttonStyle(.plain).disabled(!validEmail)
                        if let resetMsg {
                            Text(resetMsg).font(.caption).foregroundColor(Color(hex: "3f7d12"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Button { withAnimation { showEmail = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { emailFocused = true } } label: {
                            Text("Continuar con email").font(.system(size: 15, weight: .bold)).foregroundColor(Brand.soft)
                                .frame(maxWidth: .infinity).frame(height: 36)
                        }.buttonStyle(.plain)
                    }
                }

                Text("Al continuar aceptas los términos y la política de privacidad.")
                    .font(.caption2).foregroundColor(Brand.soft).multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
            .padding(24)
        }
        .alert("Falta configurar Google", isPresented: $googleNote) {
            Button("Vale", role: .cancel) {}
        } message: {
            Text("Para activar Google hay que crear un OAuth Client ID de iOS en Google Cloud y pegarlo en AuthConfig.swift (instrucciones dentro). Mientras, entra con Apple o email.")
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
                         store.syncProfileToBackend(); store.syncSessionsFromBackend() }
                    catch { print("[Backend] Google → Supabase falló:", error) }
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
                     store.syncProfileToBackend(); store.syncSessionsFromBackend() }
                catch { print("[Backend] Apple → Supabase falló:", error) }
            }
        }
    }

    private func forgotPassword() {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard validEmail, Backend.shared.isConfigured else { return }
        FX.tap()
        Task {
            try? await Backend.shared.resetPassword(email: e)
            resetMsg = "Si el correo existe, te enviamos un enlace para restablecer la contraseña."
        }
    }

    private func signInEmail() {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard canEmail, !emailBusy else { return }
        emailError = nil; resetMsg = nil
        // Sin backend configurado: identidad local simple (como antes).
        guard Backend.shared.isConfigured else {
            FX.success(sound: true)
            withAnimation { store.signIn(provider: "email", userId: e, email: e, name: nil) }
            return
        }
        emailBusy = true
        Task {
            do {
                let uid = try await Backend.shared.signInOrSignUpEmail(e, password: password)
                print("[Backend] sesión Supabase (email) abierta: \(uid)")
                FX.success(sound: true)
                withAnimation { store.signIn(provider: "email", userId: uid.uuidString, email: e, name: nil) }
                store.syncProfileToBackend(); store.syncSessionsFromBackend()
            } catch {
                print("[Backend] email → Supabase falló:", error)
                emailError = "No pudimos entrar. Revisa el correo y la contraseña."
            }
            emailBusy = false
        }
    }
}
