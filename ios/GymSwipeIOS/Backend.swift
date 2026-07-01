import Foundation
import CryptoKit
import Supabase

/// Capa de acceso a Supabase. Gateada por `BackendConfig`: si no hay credenciales,
/// `client == nil` y `isConfigured == false`, así que la app sigue funcionando en local.
///
/// Fase 1 (actual): auth con Apple/Google (ID token) + upsert del perfil.
/// Las fases siguientes (sesiones, follows, feed, ranking) se añaden aquí encima.
@MainActor
final class Backend {
    static let shared = Backend()

    let client: SupabaseClient?
    var isConfigured: Bool { client != nil }

    private init() {
        if BackendConfig.isConfigured, let url = URL(string: BackendConfig.supabaseURL) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: BackendConfig.supabaseAnonKey)
        } else {
            client = nil
        }
    }

    /// ID del usuario autenticado en Supabase (nil si no hay sesión o no está configurado).
    var currentUserId: UUID? { client?.auth.currentSession?.user.id }

    // MARK: - Auth (ID token nativo → sesión Supabase)

    /// Inicia sesión en Supabase con el ID token de Apple (requiere el `nonce` en crudo).
    @discardableResult
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID {
        guard let client else { throw BackendError.notConfigured }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
        return session.user.id
    }

    /// Inicia sesión en Supabase con el ID token de Google.
    @discardableResult
    func signInWithGoogle(idToken: String) async throws -> UUID {
        guard let client else { throw BackendError.notConfigured }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken))
        return session.user.id
    }

    func signOut() async {
        try? await client?.auth.signOut()
    }

    // MARK: - Perfil

    /// Crea/actualiza la fila de perfil del usuario actual. Solo los campos no nulos.
    func upsertProfile(_ profile: ProfileRow) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("profiles").upsert(profile).execute()
    }
}

enum BackendError: Error { case notConfigured }

/// Nonce para Sign in with Apple → Supabase: se envía el SHA256 a Apple y el crudo a Supabase.
enum AuthNonce {
    static func random(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }
    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Fila de `public.profiles`. `id` debe ser el `auth.uid()` del usuario.
struct ProfileRow: Encodable {
    let id: UUID
    var handle: String?
    var name: String?
    var avatar_url: String?
    var country: String?
    var city: String?
    var gym: String?
    var is_private: Bool?
}
