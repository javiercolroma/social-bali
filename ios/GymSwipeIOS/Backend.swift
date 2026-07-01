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

    /// Entra con email/contraseña; si el usuario no existe, lo crea. Devuelve el uid.
    @discardableResult
    func signInOrSignUpEmail(_ email: String, password: String) async throws -> UUID {
        guard let client else { throw BackendError.notConfigured }
        do {
            return try await client.auth.signIn(email: email, password: password).user.id
        } catch {
            // No existe / contraseña incorrecta → intenta registrarlo. Exigimos SESIÓN real:
            // si signUp no la devuelve (email ya existe, obfuscado), es un fallo, no un login fantasma.
            let res = try await client.auth.signUp(email: email, password: password)
            guard let session = res.session else { throw BackendError.noSession }
            return session.user.id
        }
    }

    func signOut() async {
        try? await client?.auth.signOut()
    }

    /// Envía un correo para restablecer la contraseña.
    func resetPassword(email: String) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.auth.resetPasswordForEmail(email)
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

    /// Busca usuarios reales por @handle o por nombre.
    func searchProfiles(_ query: String, limit: Int = 20) async throws -> [ProfileRow] {
        guard let client else { return [] }
        // Quita comas/paréntesis que romperían el filtro `or` de PostgREST.
        let q = query.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        guard !q.isEmpty else { return [] }
        return try await client.from("profiles")
            .select("id,handle,name,avatar_url,country,city,gym,is_private")
            .or("handle.ilike.%\(q)%,name.ilike.%\(q)%")
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

    // MARK: - Likes (kudos) y comentarios

    func likeSession(_ sessionId: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("kudos").upsert(KudosRow(user_id: me.uuidString, session_id: sessionId)).execute()
    }
    func unlikeSession(_ sessionId: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("kudos").delete()
            .eq("user_id", value: me.uuidString).eq("session_id", value: sessionId).execute()
    }
    func fetchKudos(sessionId: String) async throws -> [KudosRow] {
        guard let client else { return [] }
        return try await client.from("kudos").select().eq("session_id", value: sessionId).execute().value
    }

    @discardableResult
    func addComment(sessionId: String, text: String, parentId: String? = nil) async throws -> CommentRow {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        let rows: [CommentRow] = try await client.from("comments")
            .insert(CommentInsert(session_id: sessionId, user_id: me.uuidString, parent_id: parentId, text: text))
            .select().execute().value
        guard let first = rows.first else { throw BackendError.notConfigured }
        return first
    }
    func fetchComments(sessionId: String) async throws -> [CommentRow] {
        guard let client else { return [] }
        return try await client.from("comments").select()
            .eq("session_id", value: sessionId).order("created_at", ascending: true).execute().value
    }

    // MARK: - Mensajería 1:1

    /// Historial de la conversación con otro usuario (ambos sentidos), cronológico.
    func fetchMessages(with otherUserId: UUID) async throws -> [MessageRow] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        let a = me.uuidString, b = otherUserId.uuidString
        return try await client.from("messages").select()
            .or("and(sender_id.eq.\(a),recipient_id.eq.\(b)),and(sender_id.eq.\(b),recipient_id.eq.\(a))")
            .order("created_at", ascending: true)
            .execute().value
    }

    /// Envía un mensaje a otro usuario.
    func sendMessage(to otherUserId: UUID, text: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("messages")
            .insert(MessageInsert(sender_id: me.uuidString, recipient_id: otherUserId.uuidString, text: text))
            .execute()
    }

    // MARK: - Ranking / Liga (XP semanal real)

    /// Clasificación por XP de la semana en curso (RPC `weekly_xp_leaderboard`, solo verificado).
    func fetchWeeklyLeaderboard() async throws -> [LeaderRow] {
        guard let client else { return [] }
        return try await client.rpc("weekly_xp_leaderboard").execute().value
    }

    // MARK: - Storage (fotos). Cada archivo va bajo `<uid>/…` (lo exige la RLS de Storage).

    /// Sube el avatar del usuario y devuelve su URL pública.
    @discardableResult
    func uploadAvatar(_ data: Data) async throws -> String {
        guard let client, let uid = await currentUserIdAsync() else { throw BackendError.notConfigured }
        let path = "\(uid.uuidString)/avatar.jpg"
        _ = try await client.storage.from("avatars")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try client.storage.from("avatars").getPublicURL(path: path).absoluteString
    }

    /// Sube la foto de un entreno y devuelve su URL pública.
    @discardableResult
    func uploadSessionPhoto(_ data: Data, sessionId: String) async throws -> String {
        guard let client, let uid = await currentUserIdAsync() else { throw BackendError.notConfigured }
        let path = "\(uid.uuidString)/\(sessionId).jpg"
        _ = try await client.storage.from("session-photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try client.storage.from("session-photos").getPublicURL(path: path).absoluteString
    }
}

enum BackendError: Error { case notConfigured, noSession }

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

/// Fila del ranking semanal (RPC `weekly_xp_leaderboard`).
struct LeaderRow: Codable {
    let user_id: UUID
    let handle: String?
    let name: String?
    let avatar_url: String?
    let weekly_xp: Int
}

/// Like de `public.kudos`.
struct KudosRow: Codable {
    let user_id: String
    let session_id: String
}

/// Alta de comentario (sin id/fecha: los pone el servidor).
struct CommentInsert: Encodable {
    let session_id: String
    let user_id: String
    let parent_id: String?
    let text: String
}

/// Comentario leído de `public.comments`.
struct CommentRow: Codable {
    let id: String
    let session_id: String
    let user_id: String
    let parent_id: String?
    let text: String
    let created_at: String
}

/// Alta de mensaje (sin id/fecha).
struct MessageInsert: Encodable {
    let sender_id: String
    let recipient_id: String
    let text: String
}

/// Mensaje leído de `public.messages`.
struct MessageRow: Codable {
    let id: String
    let sender_id: String
    let recipient_id: String
    let text: String
    let created_at: String
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
    let photo_url: String?
    let visibility: String
    let verified: Bool
    let items: [SessionExercise]

    init(_ s: WorkoutSession, userId: UUID, photoURL: String? = nil) {
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
        photo_url = photoURL ?? s.photoURL   // nunca borres una URL ya conocida
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
            location: location, verified: verified, photoURL: photo_url)
    }
}
