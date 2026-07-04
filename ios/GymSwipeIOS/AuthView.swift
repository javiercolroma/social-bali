import SwiftUI
import AuthenticationServices
import GoogleSignIn

/// Bienvenida estilo Strava: primero eliges **Unirme gratis** o **Iniciar sesión**;
/// cada una abre una hoja con los proveedores (Apple / Google / email). Sin backend,
/// la identidad se guarda en local (`store.signIn`) y el onboarding monta el perfil.
struct AuthView: View {
    @State private var providerMode: ProviderMode?

    enum ProviderMode: Identifiable { case signup, login; var id: Int { self == .signup ? 0 : 1 } }

    var body: some View {
        ZStack {
            Brand.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle().fill(Brand.greenSoft).frame(width: 108, height: 108)
                    Image(systemName: "dumbbell.fill").font(.system(size: 46, weight: .heavy)).foregroundColor(Color(hex: "10150a"))
                }
                Text("Forge Loop").font(.system(size: 34, weight: .heavy)).foregroundColor(Brand.ink).padding(.top, 16)
                Text("Entrena, mide tu progreso y compite con tu gente.")
                    .font(.system(size: 16)).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 6).padding(.horizontal, 20)
                Spacer()

                Button { FX.tap(); providerMode = .signup } label: {
                    Text("Unirme gratis").frame(maxWidth: .infinity)
                }.buttonStyle(PrimaryButtonStyle())

                Button { FX.tap(); providerMode = .login } label: {
                    HStack(spacing: 5) {
                        Text("¿Ya tienes cuenta?").foregroundColor(Brand.muted)
                        Text("Iniciar sesión").foregroundColor(Brand.ink)
                    }.font(.system(size: 15, weight: .heavy)).frame(maxWidth: .infinity).frame(height: 46)
                }.buttonStyle(.plain).padding(.top, 4)

                Text("Al continuar aceptas los términos y la política de privacidad.")
                    .font(.caption2).foregroundColor(Brand.soft).multilineTextAlignment(.center).padding(.top, 8)
            }
            .padding(24)
        }
        .sheet(item: $providerMode) { mode in
            AuthProviderSheet(creating: mode == .signup)
        }
    }
}

/// Hoja de proveedores: Apple / Google / email, con el título según sea registro o login.
struct AuthProviderSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let creating: Bool
    @State private var showEmail = false
    @State private var googleNote = false
    @State private var appleNonce = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text(creating ? "Únete a Forge Loop" : "Bienvenido de nuevo")
                        .font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                    Text(creating ? "Crea tu cuenta en segundos." : "Entra para seguir con tu progreso.")
                        .font(.footnote).foregroundColor(Brand.muted)
                }.padding(.top, 26)

                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { req in
                        let nonce = AuthNonce.random(); appleNonce = nonce
                        req.requestedScopes = [.fullName, .email]
                        req.nonce = AuthNonce.sha256(nonce)
                    } onCompletion: { handleApple($0) }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52).clipShape(RoundedRectangle(cornerRadius: 14))

                    providerButton(creating ? "Registrarse con Google" : "Continuar con Google", action: { handleGoogle() }) {
                        GoogleGLogo(size: 18)
                    }
                    providerButton(creating ? "Registrarse con email" : "Continuar con email", action: { FX.tap(); showEmail = true }) {
                        Image(systemName: "envelope.fill").font(.system(size: 16, weight: .bold)).foregroundColor(Brand.ink)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .background(Brand.bg)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showEmail) { EmailAuthSheet(startCreating: creating).environmentObject(store) }
        .alert("Falta configurar Google", isPresented: $googleNote) {
            Button("Vale", role: .cancel) {}
        } message: {
            Text("Para activar Google hay que crear un OAuth Client ID de iOS en Google Cloud y pegarlo en AuthConfig.swift (instrucciones dentro). Mientras, entra con Apple o email.")
        }
    }

    private func providerButton<Leading: View>(_ label: String, action: @escaping () -> Void, @ViewBuilder leading: () -> Leading) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                leading().frame(width: 20, height: 20)
                Text(label).font(.system(size: 16, weight: .heavy))
            }
            .foregroundColor(Brand.ink).frame(maxWidth: .infinity).frame(height: 52)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
        }
    }

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
            if Backend.shared.isConfigured, let idToken = user.idToken?.tokenString {
                Task {
                    do { let uid = try await Backend.shared.signInWithGoogle(idToken: idToken)
                         print("[Backend] sesión Supabase (Google) abierta: \(uid)")
                         store.hydrateAccountFromBackend(); store.syncSessionsFromBackend(); store.syncWorkoutsFromBackend() }
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
        if Backend.shared.isConfigured, let tokenData = c.identityToken,
           let idToken = String(data: tokenData, encoding: .utf8) {
            let nonce = appleNonce
            Task {
                do { let uid = try await Backend.shared.signInWithApple(idToken: idToken, nonce: nonce)
                     print("[Backend] sesión Supabase (Apple) abierta: \(uid)")
                     store.hydrateAccountFromBackend(); store.syncSessionsFromBackend(); store.syncWorkoutsFromBackend() }
                catch { print("[Backend] Apple → Supabase falló:", error); store.checkingProfile = false }
            }
        }
    }
}

/// Email SIN contraseña (estilo Strava): 1) escribes tu correo → te enviamos un código
/// de 6 dígitos; 2) lo introduces y dentro. El modo (registro/inicio) solo cambia la copy
/// y si se crea cuenta con un correo nuevo.
struct EmailAuthSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let startCreating: Bool
    @State private var creating: Bool
    @State private var step = 0           // 0 = correo, 1 = código
    @State private var email = ""
    @State private var code = ""
    @State private var error: String?
    @State private var busy = false
    @State private var resendIn = 0       // segundos para poder reenviar
    @FocusState private var focusEmail: Bool
    @FocusState private var focusCode: Bool
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(startCreating: Bool) {
        self.startCreating = startCreating
        _creating = State(initialValue: startCreating)
    }

    private var validEmail: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        return e.contains("@") && e.contains(".") && e.count >= 6
    }
    private var cleanEmail: String { email.trimmingCharacters(in: .whitespaces).lowercased() }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if step == 0 { emailStep } else { codeStep }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Brand.bg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { focusEmail = true } }
        .onReceive(ticker) { _ in if resendIn > 0 { resendIn -= 1 } }
    }

    // MARK: - Paso 1: correo

    private var emailStep: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text(creating ? "Crea tu cuenta" : "Inicia sesión")
                    .font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Te enviaremos un código de 6 dígitos para verificar que este correo es tuyo.")
                    .font(.footnote).foregroundColor(Brand.muted)
            }
            .padding(.top, 22)

            VStack(alignment: .leading, spacing: 5) {
                Text("CORREO").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill").font(.system(size: 14)).foregroundColor(Brand.soft)
                    TextField("tu@email.com", text: $email)
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focusEmail).submitLabel(.go).onSubmit { sendCode() }
                }
                .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(focusEmail ? Brand.green : Brand.line, lineWidth: focusEmail ? 1.5 : 1))
            }

            if let error { Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundColor(Color(hex: "a73232")) }

            Button { sendCode() } label: {
                HStack(spacing: 8) {
                    if busy { ProgressView().tint(Color(hex: "10150a")) }
                    Text(busy ? "Enviando…" : "Enviar código")
                }.frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(enabled: validEmail && !busy)).disabled(!validEmail || busy)

            // Cambiar de modo por si te equivocaste al elegir en la bienvenida.
            Button { withAnimation { creating.toggle(); error = nil } } label: {
                HStack(spacing: 5) {
                    Text(creating ? "¿Ya tienes cuenta?" : "¿Eres nuevo?").foregroundColor(Brand.muted)
                    Text(creating ? "Inicia sesión" : "Crea una cuenta").foregroundColor(Brand.ink)
                }.font(.system(size: 13, weight: .heavy)).frame(maxWidth: .infinity)
            }.buttonStyle(.plain).padding(.top, 2)
        }
    }

    // MARK: - Paso 2: código

    private var codeStep: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text("Revisa tu correo").font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                Text("Hemos enviado un código de 6 dígitos a **\(cleanEmail)**.")
                    .font(.footnote).foregroundColor(Brand.muted)
            }
            .padding(.top, 22)

            // Casillas del código: un TextField oculto recoge los dígitos; las cajas los pintan.
            ZStack {
                TextField("", text: $code)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .focused($focusCode)
                    .opacity(0.02)
                    .onChange(of: code) { v in
                        let digits = String(v.filter(\.isNumber).prefix(6))
                        if digits != v { code = digits }
                        error = nil
                        if digits.count == 6 { verify() }
                    }
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { i in
                        let chars = Array(code)
                        let filled = i < chars.count
                        let isCursor = i == chars.count && focusCode
                        Text(filled ? String(chars[i]) : "")
                            .font(.system(size: 24, weight: .heavy)).foregroundColor(Brand.ink)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(isCursor ? Brand.green : (filled ? Brand.greenSoft : Brand.line),
                                        lineWidth: isCursor ? 2 : 1.2))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { focusCode = true }
            }
            .frame(height: 56)

            if let error { Label(error, systemImage: "exclamationmark.circle.fill").font(.caption).foregroundColor(Color(hex: "a73232")) }
            if busy { HStack(spacing: 8) { ProgressView(); Text("Verificando…").font(.caption).foregroundColor(Brand.muted) } }

            HStack {
                Button { withAnimation { step = 0; code = ""; error = nil }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusEmail = true } } label: {
                    Label("Cambiar correo", systemImage: "arrow.left").font(.system(size: 13, weight: .heavy)).foregroundColor(Brand.soft)
                }.buttonStyle(.plain)
                Spacer()
                Button { sendCode(resend: true) } label: {
                    Text(resendIn > 0 ? "Reenviar en \(resendIn)s" : "Reenviar código")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(resendIn > 0 ? Brand.soft : Brand.ink)
                }.buttonStyle(.plain).disabled(resendIn > 0 || busy)
            }.padding(.top, 4)
        }
    }

    // MARK: - Acciones

    private func sendCode(resend: Bool = false) {
        guard validEmail, !busy else { return }
        error = nil
        guard Backend.shared.isConfigured else {
            // Sin backend (desarrollo local): entra directo.
            FX.success(sound: true); dismiss()
            withAnimation { store.signIn(provider: "email", userId: cleanEmail, email: cleanEmail, name: nil) }
            return
        }
        busy = true
        Task {
            do {
                try await Backend.shared.sendEmailCode(cleanEmail, createIfNeeded: creating)
                FX.tap()
                resendIn = 30
                if !resend { withAnimation { step = 1; code = "" } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focusCode = true }
            } catch {
                print("[Backend] enviar código falló:", error)
                let msg = String(describing: error).lowercased()
                if msg.contains("signup") || msg.contains("otp_disabled") {
                    self.error = "No existe ninguna cuenta con este correo. ¿Eres nuevo? Elige «Crea una cuenta»."
                } else if msg.contains("rate") {
                    self.error = "Demasiados intentos. Espera un minuto y vuelve a probar."
                } else {
                    self.error = "No pudimos enviar el código. Revisa el correo e inténtalo de nuevo."
                }
            }
            busy = false
        }
    }

    private func verify() {
        guard code.count == 6, !busy else { return }
        busy = true
        Task {
            do {
                let uid = try await Backend.shared.verifyEmailCode(cleanEmail, code: code)
                print("[Backend] sesión Supabase (email OTP) abierta: \(uid)")
                FX.success(sound: true); dismiss()
                withAnimation { store.signIn(provider: "email", userId: uid.uuidString, email: cleanEmail, name: nil) }
                store.hydrateAccountFromBackend(); store.syncSessionsFromBackend(); store.syncWorkoutsFromBackend()
            } catch {
                print("[Backend] verificar código falló:", error)
                self.error = "Código incorrecto o caducado. Revísalo o pide uno nuevo."
                code = ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focusCode = true }
            }
            busy = false
        }
    }
}

/// Logotipo "G" de Google (4 colores) dibujado en SwiftUI, sin necesidad de imágenes.
/// Anillo abierto por la derecha (rojo arriba, amarillo izquierda, verde abajo, azul
/// arriba-derecha) + barra horizontal azul.
struct GoogleGLogo: View {
    var size: CGFloat = 18
    private let blue = Color(red: 0.259, green: 0.522, blue: 0.957)   // #4285F4
    private let red = Color(red: 0.918, green: 0.263, blue: 0.208)    // #EA4335
    private let yellow = Color(red: 0.984, green: 0.737, blue: 0.020) // #FBBC05
    private let green = Color(red: 0.204, green: 0.659, blue: 0.325)  // #34A853

    var body: some View {
        let lw = size * 0.28
        ZStack {
            seg(0.60, 0.88, red, lw)      // arco superior
            seg(0.35, 0.60, yellow, lw)   // arco izquierdo
            seg(0.10, 0.35, green, lw)    // arco inferior
            seg(0.88, 1.00, blue, lw)     // arco superior-derecha (hacia la barra)
            // Barra horizontal azul (lo que hace que sea una "G" y no un anillo).
            Capsule().fill(blue)
                .frame(width: size * 0.40, height: lw)
                .offset(x: size * 0.23, y: size * 0.02)
        }
        .frame(width: size, height: size)
    }

    private func seg(_ from: CGFloat, _ to: CGFloat, _ color: Color, _ lw: CGFloat) -> some View {
        Circle().trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: lw, lineCap: .butt))
            .frame(width: size, height: size)
    }
}
