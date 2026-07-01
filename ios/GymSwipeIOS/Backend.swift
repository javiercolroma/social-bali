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

    /// Igual, pero espera a que el SDK restaure la sesión persistida (útil en el arranque en frío).
    func currentUserIdAsync() async -> UUID? {
        if let s = client?.auth.currentSession { return s.user.id }
        return try? await client?.auth.session.user.id
    }

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

    // MARK: - Sesiones de entreno

    /// Sube (o actualiza) una sesión de entreno. Idempotente por `id`.
    func upsertSession(_ row: SessionRow) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("workout_sessions").upsert(row).execute()
    }

    /// Trae las sesiones del usuario actual, más recientes primero.
    func fetchMySessions() async throws -> [SessionRow] {
        guard let client, let uid = await currentUserIdAsync() else { return [] }
        return try await client.from("workout_sessions")
            .select()
            .eq("user_id", value: uid.uuidString)
            .order("date", ascending: false)
            .execute()
            .value
    }

    // MARK: - Grafo social (follows) y feed

    /// Seguir / solicitar (privadas → status "pending" hasta que acepten).
    func setFollow(_ userId: UUID, status: String = "accepted") async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("follows")
            .upsert(FollowRow(follower_id: me.uuidString, following_id: userId.uuidString, status: status))
            .execute()
    }

    func unfollow(_ userId: UUID) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("follows").delete()
            .eq("follower_id", value: me.uuidString)
            .eq("following_id", value: userId.uuidString)
            .execute()
    }

    /// A quién sigo (con su estado pendiente/aceptado).
    func fetchFollowing() async throws -> [FollowRow] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        return try await client.from("follows").select().eq("follower_id", value: me.uuidString).execute().value
    }

    /// Quién me sigue.
    func fetchFollowers() async throws -> [FollowRow] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        return try await client.from("follows").select().eq("following_id", value: me.uuidString).execute().value
    }

    /// Busca usuarios reales por @handle.
    func searchProfiles(_ query: String, limit: Int = 20) async throws -> [ProfileRow] {
        guard let client, !query.isEmpty else { return [] }
        return try await client.from("profiles")
            .select("id,handle,name,avatar_url,country,city,gym,is_private")
            .ilike("handle", value: "%\(query)%")
            .limit(limit)
            .execute().value
    }

    func fetchProfiles(ids: [UUID]) async throws -> [ProfileRow] {
        guard let client, !ids.isEmpty else { return [] }
        return try await client.from("profiles")
            .select("id,handle,name,avatar_url,country,city,gym,is_private")
            .in("id", values: ids.map { $0.uuidString })
            .execute().value
    }

    /// Feed: la RLS ya filtra a lo que puedes ver (lo tuyo + público + a quien sigues).
    func fetchFeed(limit: Int = 50) async throws -> [SessionRow] {
        guard let client else { return [] }
        return try await client.from("workout_sessions")
            .select()
            .order("date", ascending: false)
            .limit(limit)
            .execute().value
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
struct ProfileRow: Codable {
    let id: UUID
    var handle: String?
    var name: String?
    var avatar_url: String?
    var country: String?
    var city: String?
    var gym: String?
    var is_private: Bool?
}

/// Fila de `public.follows` (grafo social estilo Instagram).
struct FollowRow: Codable {
    let follower_id: String
    let following_id: String
    let status: String
}

/// Fecha ↔ `timestamptz`. Escribimos ISO8601 con milisegundos; al leer somos tolerantes
/// porque Postgres devuelve microsegundos (6 dígitos), que el parser estricto rechaza.
enum BackendDate {
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parse(_ s: String) -> Date? {
        if let d = iso.date(from: s) { return d }
        // Quita la parte fraccionaria de cualquier longitud y reintenta sin ella.
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let stripped = s.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: stripped)
    }
}

/// Fila de `public.workout_sessions`. `id` es el mismo id (UUID) que la sesión local.
struct SessionRow: Codable {
    let id: String
    let user_id: String
    let name: String
    let note: String?
    let date: String
    let elapsed: Int
    let exercises: Int
    let sets: Int
    let volume: Double
    let xp: Int
    let avg_hr: Int?
    let max_hr: Int?
    let location: String?
    let visibility: String
    let verified: Bool
    let items: [SessionExercise]

    init(_ s: WorkoutSession, userId: UUID) {
        id = s.id
        user_id = userId.uuidString
        name = s.name
        note = s.note.isEmpty ? nil : s.note
        date = BackendDate.iso.string(from: s.date)
        elapsed = s.elapsed
        exercises = s.exercises
        sets = s.sets
        volume = s.volume
        xp = s.xp
        avg_hr = s.avgHeartRate
        max_hr = s.maxHeartRate
        location = s.location
        visibility = s.visibility.rawValue
        verified = s.verified
        items = s.items ?? []
    }

    /// Sesión local a partir de la fila del servidor (la foto llegará con Storage, Fase 5).
    var asWorkoutSession: WorkoutSession {
        WorkoutSession(
            id: id, name: name, note: note ?? "",
            date: BackendDate.parse(date) ?? Date(),
            elapsed: elapsed, exercises: exercises, sets: sets, volume: volume, xp: xp,
            photoData: nil, visibility: WorkoutVisibility(rawValue: visibility) ?? .all,
            items: items, avgHeartRate: avg_hr, maxHeartRate: max_hr,
            location: location, verified: verified)
    }
}
