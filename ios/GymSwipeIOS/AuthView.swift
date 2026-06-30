import SwiftUI
import AuthenticationServices

/// Pantalla de inicio de sesión / registro. Sin backend todavía: la identidad del
/// proveedor se guarda localmente (`store.signIn`). Tras entrar, el onboarding monta el perfil.
struct AuthView: View {
    @EnvironmentObject var store: AppStore
    @State private var showEmail = false
    @State private var email = ""
    @State private var googleNote = false
    @FocusState private var emailFocused: Bool

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
                        req.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleApple(result)
                    }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52).clipShape(RoundedRectangle(cornerRadius: 14))

                    Button { FX.tap(); googleNote = true } label: {
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
                                .autocorrectionDisabled().focused($emailFocused).submitLabel(.go)
                                .onSubmit { if validEmail { signInEmail() } }
                        }
                        .padding(.horizontal, 14).frame(height: 52).background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(emailFocused ? Brand.greenSoft : Brand.line, lineWidth: emailFocused ? 1.5 : 1))
                        Button { signInEmail() } label: { Text("Continuar") }
                            .buttonStyle(PrimaryButtonStyle(enabled: validEmail)).disabled(!validEmail)
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
        .alert("Google llegará pronto", isPresented: $googleNote) {
            Button("Vale", role: .cancel) {}
        } message: {
            Text("El inicio de sesión con Google estará disponible en cuanto conectemos las credenciales. De momento usa Apple o email.")
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result,
              let c = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let name = [c.fullName?.givenName, c.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        FX.success(sound: true)
        withAnimation { store.signIn(provider: "apple", userId: c.user, email: c.email, name: name.isEmpty ? nil : name) }
    }

    private func signInEmail() {
        let e = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard validEmail else { return }
        FX.success(sound: true)
        withAnimation { store.signIn(provider: "email", userId: e, email: e, name: nil) }
    }
}
