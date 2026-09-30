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

    /// Inicia sesión con email/contraseña (falla si las credenciales no son válidas).
    @discardableResult
    // Email SIN contraseña (estilo Strava): se envía un código de 6 dígitos al correo
    // (SMTP Resend + plantillas con {{ .Token }}) y `verifyEmailCode` abre la sesión.

    /// Envía el código. `createIfNeeded`: en REGISTRO crea la cuenta si no existe; en
    /// INICIO DE SESIÓN va a false → un correo no registrado da error (y no una cuenta nueva).
    func sendEmailCode(_ email: String, createIfNeeded: Bool) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: createIfNeeded)
    }

    /// Verifica el código de 6 dígitos y devuelve el usuario ya autenticado.
    func verifyEmailCode(_ email: String, code: String) async throws -> UUID {
        guard let client else { throw BackendError.notConfigured }
        let res = try await client.auth.verifyOTP(email: email, token: code, type: .email)
        return res.user.id
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

    /// Fecha de nacimiento: va en `profile_private` (solo la lee su dueño), NO en
    /// `profiles`, que es pública dentro del club. Ver migración 0024.
    func upsertMyBirthdate(_ date: Date) async throws {
        guard let client, let uid = await currentUserIdAsync() else { throw BackendError.notConfigured }
        struct Row: Encodable { let id: String; let birthdate: String }
        try await client.from("profile_private")
            .upsert(Row(id: uid.uuidString.lowercased(), birthdate: StayDate.string(from: date)), returning: .minimal)
            .execute()
    }

    func fetchMyBirthdate() async throws -> Date? {
        guard let client, let uid = await currentUserIdAsync() else { return nil }
        struct Row: Decodable { let birthdate: String? }
        let rows: [Row] = try await client.from("profile_private").select("birthdate")
            .eq("id", value: uid.uuidString.lowercased()).limit(1).execute().value
        return rows.first?.birthdate.flatMap(StayDate.date(from:))
    }

    // MARK: - Discover («Today's People», migración 0025)

    /// El mazo de hoy (día de Bali). Lo calcula y guarda el servidor: siempre el mismo.
    func todaysPeople() async throws -> DiscoverDeck {
        guard let client else { throw BackendError.notConfigured }
        // En frío, `currentSession` puede traer un token CADUCADO: la RPC salía con él, el
        // servidor la rechazaba y Descubrir enseñaba «sin conexión» hasta refrescar a mano.
        // `auth.session` espera a la sesión restaurada y renueva el token si hace falta.
        _ = try await client.auth.session
        return try await client.rpc("todays_people").execute().value
    }

    /// Your Circle (0028): el mazo de hoy + distancia, online e indicador de cada persona.
    func yourCircle() async throws -> CircleDeck {
        guard let client else { throw BackendError.notConfigured }
        _ = try await client.auth.session   // token renovado (ver todaysPeople)
        return try await client.rpc("your_circle").execute().value
    }

    // MARK: - Presencia de Your Circle (0028)

    /// El servidor ajusta la posición a ~110 m antes de guardarla y nadie la puede leer.
    func updatePresenceExact(lat: Double, lon: Double) async {
        guard let client else { return }
        struct P: Encodable { let lat: Double; let lon: Double }
        do { try await client.rpc("update_presence", params: P(lat: lat, lon: lon)).execute() }
        catch { print("[Backend] presencia falló:", error) }
    }

    func heartbeat() async {
        guard let client, client.auth.currentSession != nil else { return }
        _ = try? await client.rpc("heartbeat").execute()
    }

    func goOffline() async {
        guard let client, client.auth.currentSession != nil else { return }
        _ = try? await client.rpc("go_offline").execute()
    }

    /// Mostrar mi distancia / mi online a los demás.
    func setPresenceVisibility(showDistance: Bool, showOnline: Bool) async {
        guard let client, let me = await currentUserIdAsync() else { return }
        struct V: Encodable { let show_distance: Bool; let show_online: Bool }
        do {
            try await client.from("profiles").update(V(show_distance: showDistance, show_online: showOnline))
                .eq("id", value: me.uuidString).execute()
        } catch { print("[Backend] privacidad de presencia falló:", error) }
    }

    func fetchPresenceVisibility() async -> (showDistance: Bool, showOnline: Bool)? {
        guard let client, let me = await currentUserIdAsync() else { return nil }
        struct V: Decodable { let show_distance: Bool?; let show_online: Bool? }
        guard let v: V = try? await client.from("profiles").select("show_distance,show_online")
            .eq("id", value: me.uuidString).single().execute().value else { return nil }
        return (v.show_distance ?? true, v.show_online ?? true)
    }

    /// Cuántos perfiles del mazo de hoy has visto (el servidor solo lo deja avanzar).
    func setDiscoverPosition(_ pos: Int) async {
        guard let client else { return }
        struct P: Encodable { let pos: Int }
        do { try await client.rpc("discover_set_position", params: P(pos: pos)).execute() }
        catch { print("[Backend] posición de Discover falló:", error) }
    }

    // MARK: - Fotos de actividad (0027)

    /// Sube una foto «haciendo lo que te gusta» y devuelve su URL pública.
    func uploadActivityPhoto(_ data: Data) async throws -> String {
        guard let client, let uid = await currentUserIdAsync() else { throw BackendError.notConfigured }
        let path = "\(uid.uuidString.lowercased())/activity-\(UUID().uuidString.lowercased()).jpg"
        _ = try await client.storage.from("avatars")
            .upload(path, data: compressedImageData(data), options: FileOptions(contentType: "image/jpeg", upsert: false))
        return try client.storage.from("avatars").getPublicURL(path: path).absoluteString
    }

    /// Borra el fichero de una foto de actividad (best-effort).
    func deleteActivityPhoto(_ url: String) async {
        guard let client, let r = url.range(of: "/avatars/") else { return }
        _ = try? await client.storage.from("avatars").remove(paths: [String(url[r.upperBound...])])
    }

    // MARK: - Sesiones de entreno

    /// Sube (o actualiza) una sesión de entreno. Idempotente por `id`.
    func upsertSession(_ row: SessionRow) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("workout_sessions").upsert(row).execute()
    }

    // MARK: - Eliminar cuenta (App Store 5.1.1: obligatorio con registro)

    /// Borra la cuenta COMPLETA del usuario actual: archivos de Storage (best-effort) y la
    /// fila de auth.users vía RPC `delete_my_account` (las cascadas arrastran perfil, sesiones,
    /// follows, mensajes, kudos, comentarios, entrenos…). Después cierra la sesión Supabase.
    func deleteAccount() async throws {
        guard let client else { throw BackendError.notConfigured }
        if let uid = await currentUserIdAsync() {
            let dir = uid.uuidString.lowercased()
            if let files = try? await client.storage.from("session-photos").list(path: dir) {
                let paths = files.map { "\(dir)/\($0.name)" }
                if !paths.isEmpty { _ = try? await client.storage.from("session-photos").remove(paths: paths) }
            }
            _ = try? await client.storage.from("avatars").remove(paths: ["\(dir)/avatar.jpg"])
        }
        try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut()
    }

    // MARK: - Solicitudes de seguimiento (cuentas privadas)

    /// Solicitudes RECIBIDAS pendientes de aceptar (gente que quiere seguirte).
    func fetchFollowRequests() async throws -> [FollowRow] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        return try await client.from("follows").select()
            .eq("following_id", value: me.uuidString).eq("status", value: "pending").execute().value
    }
    func acceptFollowRequest(from follower: UUID) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("follows").update(["status": "accepted"])
            .eq("follower_id", value: follower.uuidString).eq("following_id", value: me.uuidString).execute()
    }
    func rejectFollowRequest(from follower: UUID) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("follows").delete()
            .eq("follower_id", value: follower.uuidString).eq("following_id", value: me.uuidString).execute()
    }

    /// Borra una sesión de entreno del servidor (y su foto de Storage, best-effort).
    func deleteSession(id: String) async {
        guard let client, let me = await currentUserIdAsync() else { return }
        _ = try? await client.storage.from("session-photos")
            .remove(paths: ["\(me.uuidString.lowercased())/\(id.lowercased()).jpg"])
        _ = try? await client.from("workout_sessions").delete().eq("id", value: id).execute()
    }

    // MARK: - Partner (planes de entrenamiento REALES)

    func fetchTrainingPlans() async throws -> [TrainingPlanRow] {
        guard let client else { return [] }
        return try await client.from("training_plans")
            .select("id,user_id,title,when_text,place,spots,note,created_at,cell_lat,cell_lon,author:profiles!training_plans_user_id_fkey(handle,name,avatar_url)")
            .gte("created_at", value: BackendDate.iso.string(from: Date().addingTimeInterval(-14 * 24 * 3600)))
            .order("created_at", ascending: false)
            .limit(50)
            .execute().value
    }
    func createTrainingPlan(title: String, when: String, place: String, spots: String, note: String?) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        struct Ins: Encodable { let user_id: String; let title: String; let when_text: String; let place: String; let spots: String; let note: String? }
        try await client.from("training_plans")
            .insert(Ins(user_id: me.uuidString.lowercased(), title: title, when_text: when, place: place, spots: spots, note: note)).execute()
    }
    func deleteTrainingPlan(id: String) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("training_plans").delete().eq("id", value: id).execute()
    }

    // MARK: - Presencia + mapa de calor (privacidad: celda de ~5 km, nunca exacta)

    /// Redondea a la celda de 0,05° (~5 km) y actualiza tu presencia. NUNCA se sube
    /// la ubicación exacta — solo la celda y la marca de actividad.
    func updatePresence(lat: Double, lon: Double) async {
        guard let client, let me = await currentUserIdAsync() else { return }
        struct P: Encodable { let geo_cell_lat: Double; let geo_cell_lon: Double; let active_at: String }
        let cell = P(geo_cell_lat: (lat / 0.05).rounded() * 0.05,
                     geo_cell_lon: (lon / 0.05).rounded() * 0.05,
                     active_at: BackendDate.iso.string(from: Date()))
        _ = try? await client.from("profiles").update(cell).eq("id", value: me.uuidString).execute()
    }

    /// Marca actividad SIN ubicación (al abrir la app): cuenta para "activos", no para el mapa.
    func touchPresence() async {
        guard let client, let me = await currentUserIdAsync() else { return }
        struct T: Encodable { let active_at: String }
        _ = try? await client.from("profiles").update(T(active_at: BackendDate.iso.string(from: Date())))
            .eq("id", value: me.uuidString).execute()
    }

    /// ¿Está libre este @usuario? (excluyendo al propio usuario). nil = no se pudo comprobar.
    func isHandleAvailable(_ handle: String) async -> Bool? {
        guard let client else { return nil }
        let h = handle.trimmingCharacters(in: .whitespaces).lowercased()
        guard !h.isEmpty else { return nil }
        struct Row: Decodable { let id: UUID }
        guard let rows: [Row] = try? await client.from("profiles").select("id")
            .ilike("handle", pattern: h).limit(1).execute().value else { return nil }
        if rows.isEmpty { return true }
        let me = await currentUserIdAsync()
        return rows.first?.id == me   // tu propio handle actual cuenta como disponible
    }

    /// Registra una petición de IA (persistente por usuario y día; ver 0019_ai_usage).
    func bumpAIUsage(kind: String, inTokens: Int = 0, outTokens: Int = 0) async {
        guard let client else { return }
        struct P: Encodable { let p_kind: String; let p_in: Int; let p_out: Int }
        _ = try? await client.rpc("bump_ai_usage", params: P(p_kind: kind, p_in: inTokens, p_out: outTokens)).execute()
    }

    /// Sube MI Gym Score al perfil (fuente única para badges de feed/búsquedas).
    func pushGymScore(_ score: Int) async {
        guard let client, let me = await currentUserIdAsync() else { return }
        _ = try? await client.from("profiles").update(["gym_score": score])
            .eq("id", value: me.uuidString).execute()
    }

    /// Mi celda (~5 km) guardada en el perfil; para calcular distancias aproximadas.
    func fetchMyCell() async -> (Double, Double)? {
        guard let client, let me = await currentUserIdAsync() else { return nil }
        struct C: Codable { let geo_cell_lat: Double?; let geo_cell_lon: Double? }
        let c: C? = try? await client.from("profiles").select("geo_cell_lat,geo_cell_lon")
            .eq("id", value: me.uuidString).single().execute().value
        guard let la = c?.geo_cell_lat, let lo = c?.geo_cell_lon else { return nil }
        return (la, lo)
    }

    /// Celdas agregadas (celda → nº de usuarios activos 30 días). Sin identidades.
    func fetchHeatmap() async throws -> [HeatCell] {
        guard let client else { return [] }
        return try await client.rpc("activity_heatmap").execute().value
    }
    func fetchActiveUsersCount() async throws -> Int {
        guard let client else { return 0 }
        return try await client.rpc("active_users_count").execute().value
    }

    // MARK: - Push (token del dispositivo)

    /// Registra/actualiza el token APNs del dispositivo para poder recibir pushes.
    func upsertDeviceToken(_ token: String) async throws {
        guard let client, let uid = await currentUserIdAsync() else { return }
        struct Row: Codable { let token: String; let user_id: String; let platform: String }
        try await client.from("device_tokens")
            .upsert(Row(token: token, user_id: uid.uuidString.lowercased(), platform: "ios")).execute()
    }

    // MARK: - Entrenos creados (plantillas) — para que no se pierdan al cerrar sesión

    func upsertWorkout(_ row: WorkoutRow) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("workouts").upsert(row).execute()
    }
    func deleteWorkout(id: String) async throws {
        guard let client else { throw BackendError.notConfigured }
        try await client.from("workouts").delete().eq("id", value: id).execute()
    }
    /// Entrenos del usuario actual (RLS ya los limita a los suyos), más recientes primero.
    func fetchMyWorkouts() async throws -> [WorkoutRow] {
        guard let client else { throw BackendError.notConfigured }
        return try await client.from("workouts").select().order("updated_at", ascending: false).execute().value
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

    /// Sesiones de OTRO usuario (la RLS ya filtra a lo que puedes ver de él).
    func fetchUserSessions(_ userId: String) async throws -> [SessionRow] {
        guard let client else { return [] }
        return try await client.from("workout_sessions").select()
            .eq("user_id", value: userId).order("date", ascending: false).execute().value
    }

    /// Contadores públicos de seguidores/seguidos de un usuario (RPC).
    func followCounts(_ userId: String) async throws -> (followers: Int, following: Int) {
        guard let client else { return (0, 0) }
        let rows: [FollowCountRow] = try await client.rpc("follow_counts", params: ["uid": userId]).execute().value
        guard let r = rows.first else { return (0, 0) }
        return (r.followers, r.following)
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
            .select(ProfileRow.columns)
            .or("handle.ilike.%\(q)%,name.ilike.%\(q)%")
            .limit(limit)
            .execute().value
    }

    /// Usuarios recientes para "A quién seguir" (yo y los ya seguidos se filtran en el cliente).
    func fetchSuggestedProfiles(limit: Int = 30) async throws -> [ProfileRow] {
        guard let client else { return [] }
        return try await client.from("profiles")
            .select(ProfileRow.columns)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute().value
    }

    /// El perfil del usuario autenticado (para saber si ya se onboardeó).
    func fetchMyProfile() async throws -> ProfileRow? {
        guard let client, let uid = await currentUserIdAsync() else { return nil }
        let rows: [ProfileRow] = try await client.from("profiles")
            .select(ProfileRow.columns)
            .eq("id", value: uid.uuidString).limit(1).execute().value
        return rows.first
    }

    func fetchProfiles(ids: [UUID]) async throws -> [ProfileRow] {
        guard let client, !ids.isEmpty else { return [] }
        return try await client.from("profiles")
            .select(ProfileRow.columns)
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

    /// Feed con el autor incrustado (join a profiles) para pintar nombre/avatar reales.
    func fetchFeedWithAuthors(limit: Int = 50) async throws -> [FeedRow] {
        guard let client else { return [] }
        return try await client.from("workout_sessions")
            .select("id,user_id,name,note,date,elapsed,exercises,sets,volume,xp,avg_hr,max_hr,location,photo_url,visibility,verified,items,insights,medals,author:profiles!workout_sessions_user_id_fkey(handle,name,avatar_url,gym_score),kudos(count),comments(count)")
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

    /// IDs de sesiones a las que YO he dado like (para pintar el corazón relleno).
    func likedSessionIds() async throws -> [String] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        let rows: [KudosRow] = try await client.from("kudos")
            .select("user_id,session_id").eq("user_id", value: me.uuidString).execute().value
        return rows.map { $0.session_id }
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

    /// Comentarios con el autor incrustado (para pintar nombre/@usuario reales).
    func fetchCommentsWithAuthors(sessionId: String) async throws -> [CommentAuthorRow] {
        guard let client else { return [] }
        return try await client.from("comments")
            .select("id,user_id,parent_id,text,created_at,author:profiles!comments_user_id_fkey(handle,name,avatar_url)")
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

    /// Todos mis mensajes recientes (para construir la lista de conversaciones).
    func fetchRecentMessages(limit: Int = 300) async throws -> [MessageRow] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        let m = me.uuidString
        return try await client.from("messages").select()
            .or("sender_id.eq.\(m),recipient_id.eq.\(m)")
            .order("created_at", ascending: false).limit(limit).execute().value
    }

    /// Marca como leídos los mensajes que te ha enviado ese usuario.
    func markMessagesRead(from otherUserId: UUID) async {
        guard let client, let me = await currentUserIdAsync() else { return }
        _ = try? await client.from("messages").update(["read": true])
            .eq("recipient_id", value: me.uuidString)
            .eq("sender_id", value: otherUserId.uuidString)
            .eq("read", value: false)
            .execute()
    }

    /// Envía un mensaje a otro usuario.
    func sendMessage(to otherUserId: UUID, text: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("messages")
            .insert(MessageInsert(sender_id: me.uuidString, recipient_id: otherUserId.uuidString, text: text))
            .execute()
    }

    // MARK: - Moderación (reportar / bloquear)

    /// Reporta contenido ('session' | 'comment' | 'user'). Idempotente por reporter+target.
    func report(targetType: String, targetId: String, reportedUserId: String?, reason: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("reports")
            .upsert(ReportInsert(reporter_id: me.uuidString, target_type: targetType, target_id: targetId,
                                 reported_user_id: reportedUserId, reason: reason),
                    onConflict: "reporter_id,target_type,target_id")
            .execute()
    }

    func blockUser(_ userId: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("blocks").upsert(BlockRow(blocker_id: me.uuidString, blocked_id: userId)).execute()
    }
    func unblockUser(_ userId: String) async throws {
        guard let client, let me = await currentUserIdAsync() else { throw BackendError.notConfigured }
        try await client.from("blocks").delete()
            .eq("blocker_id", value: me.uuidString).eq("blocked_id", value: userId).execute()
    }
    func blockedIds() async throws -> [String] {
        guard let client, let me = await currentUserIdAsync() else { return [] }
        let rows: [BlockRow] = try await client.from("blocks").select().eq("blocker_id", value: me.uuidString).execute().value
        return rows.map { $0.blocked_id }
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
        let path = "\(uid.uuidString.lowercased())/avatar.jpg"
        _ = try await client.storage.from("avatars")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try client.storage.from("avatars").getPublicURL(path: path).absoluteString
    }

    /// Sube la foto de un entreno y devuelve su URL pública.
    @discardableResult
    func uploadSessionPhoto(_ data: Data, sessionId: String) async throws -> String {
        guard let client, let uid = await currentUserIdAsync() else { throw BackendError.notConfigured }
        let path = "\(uid.uuidString.lowercased())/\(sessionId.lowercased()).jpg"
        _ = try await client.storage.from("session-photos")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return try client.storage.from("session-photos").getPublicURL(path: path).absoluteString
    }
}

enum BackendError: Error { case notConfigured, noSession, emailTaken }

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
    /// Columnas que se LEEN. Incluye las del club: si falta una, `hydrateAccountFromBackend`
    /// la leería como nil y borraría la identidad local al reinstalar.
    static let columns = "id,handle,name,avatar_url,country,city,gym,is_private,"
        + "bio,sports,neighborhood,home_city,home_country,stay_kind,stay_until,intents,photos"

    let id: UUID
    var handle: String?
    var name: String?
    var avatar_url: String?
    var country: String?
    var city: String?
    var gym: String?
    var is_private: Bool?
    var gym_score: Int?

    // ─── Club social (migración 0023) ────────────────────────────────────────
    // Opcionales: hay perfiles en producción sin nada de esto.
    var bio: String?
    var sports: [String]?
    var neighborhood: String?
    var home_city: String?
    var home_country: String?
    var stay_kind: String?
    /// `date` en Postgres → se manda como "yyyy-MM-dd" en texto, no como Date: el
    /// codificador por defecto emite un timestamp ISO completo y la columna es `date`.
    var stay_until: String?
    var intents: [String]?
    /// Hasta 4 fotos «haciendo lo que te gusta» (0027).
    var photos: [String]?
    /// Fotos de sus últimos entrenos públicos. Solo llega en Descubrir; NO es columna.
    var moments: [String]?

    // ─── Solo en Your Circle (0028); NO son columnas y no se envían ───────────
    var age: Int?
    /// Metros ya redondeados por el servidor; nil si esa persona la oculta o no hay ubicación.
    var distance_m: Int?
    var online: Bool?
    /// new · new_in_area · leaving · nearby
    var badge: String?
    var days_left: Int?
    /// Primera vez que aparece en MI Circle (para «4 new»).
    var first_time: Bool?

    /// Los campos del club y las fotos se mandan SIEMPRE, también como `null`: el
    /// `Encodable` sintetizado omite los nil, y entonces borrar tu bio (o tu última foto)
    /// no llegaba nunca al servidor, que conservaba el valor viejo. El resto se omite si
    /// es nil, a propósito: `avatar_url` nil significa «sin cambios», no «borra la foto».
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(handle, forKey: .handle)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(avatar_url, forKey: .avatar_url)
        try c.encodeIfPresent(country, forKey: .country)
        try c.encodeIfPresent(city, forKey: .city)
        try c.encodeIfPresent(gym, forKey: .gym)
        try c.encodeIfPresent(is_private, forKey: .is_private)
        try c.encodeIfPresent(gym_score, forKey: .gym_score)
        try c.encode(bio, forKey: .bio)
        try c.encode(sports, forKey: .sports)
        try c.encode(neighborhood, forKey: .neighborhood)
        try c.encode(home_city, forKey: .home_city)
        try c.encode(home_country, forKey: .home_country)
        try c.encode(stay_kind, forKey: .stay_kind)
        try c.encode(stay_until, forKey: .stay_until)
        try c.encode(intents, forKey: .intents)
        try c.encode(photos, forKey: .photos)
        // `moments` no se envía: no es una columna.
    }

    var club: ClubIdentity {
        ClubIdentity(bio: bio, sports: sports, neighborhood: neighborhood, homeCity: home_city,
                     homeCountry: home_country, stayKind: stay_kind,
                     stayUntil: stay_until.flatMap(StayDate.date(from:)), intents: intents)
    }
}

/// Respuesta de `todays_people()`: tarjetas en el orden del mazo + por dónde vas.
struct DiscoverDeck: Decodable {
    let day: String
    let position: Int
    let profiles: [ProfileRow]
}

struct CircleDeck: Decodable {
    let day: String
    let position: Int
    /// Mi barrio declarado (cabecera «YOUR CIRCLE · Canggu»).
    let area: String?
    let profiles: [ProfileRow]
}

/// Formato de `profiles.stay_until` (columna `date` de Postgres).
enum StayDate {
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func string(from date: Date) -> String { fmt.string(from: date) }
    static func date(from string: String) -> Date? { fmt.date(from: String(string.prefix(10))) }
}

/// Fila de `public.follows` (grafo social estilo Instagram).
struct FollowRow: Codable {
    let follower_id: String
    let following_id: String
    let status: String
}

/// Autor incrustado en el feed.
struct FeedAuthor: Codable { let handle: String?; let name: String?; let avatar_url: String?; let gym_score: Int? }

/// Contador incrustado (PostgREST `tabla(count)` → `[{count: N}]`).
struct CountRow: Codable { let count: Int }

/// Fila del feed = sesión + autor (join a profiles).
struct FeedRow: Codable {
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
    let insights: [ProgressInsight]?
    let medals: [SessionMedal]?
    let author: FeedAuthor?
    let kudos: [CountRow]?
    let comments: [CountRow]?
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

/// Resultado del RPC `follow_counts`.
struct FollowCountRow: Codable { let followers: Int; let following: Int }

/// Alta de reporte de contenido.
struct ReportInsert: Encodable {
    let reporter_id: String
    let target_type: String
    let target_id: String
    let reported_user_id: String?
    let reason: String?
}

/// Bloqueo de usuario.
struct BlockRow: Codable {
    let blocker_id: String
    let blocked_id: String
}

/// Alta de comentario (sin id/fecha: los pone el servidor).
struct CommentInsert: Encodable {
    let session_id: String
    let user_id: String
    let parent_id: String?
    let text: String
}

/// Comentario con autor incrustado (para el feed).
struct CommentAuthorRow: Codable {
    let id: String
    let user_id: String
    let parent_id: String?
    let text: String
    let created_at: String
    let author: FeedAuthor?
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
    var read: Bool? = nil
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
    let insights: [ProgressInsight]?   // avances por-ejercicio (jsonb); para que tus seguidores los vean
    let medals: [SessionMedal]?        // logros/medallas del entreno (jsonb)

    init(_ s: WorkoutSession, userId: UUID, photoURL: String? = nil) {
        id = s.id.lowercased()   // determinista: Postgres normaliza el UUID a minúscula
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
        insights = s.insights
        medals = s.medals
    }

    /// Sesión local a partir de la fila del servidor (la foto llegará con Storage, Fase 5).
    var asWorkoutSession: WorkoutSession {
        WorkoutSession(
            id: id, name: name, note: note ?? "",
            date: BackendDate.parse(date) ?? Date(),
            elapsed: elapsed, exercises: exercises, sets: sets, volume: volume, xp: xp,
            photoData: nil, visibility: WorkoutVisibility(rawValue: visibility) ?? .all,
            items: items, avgHeartRate: avg_hr, maxHeartRate: max_hr,
            location: location, verified: verified, photoURL: photo_url, insights: insights, medals: medals)
    }
}

/// Plan de entrenamiento real (Partner), con su autor embebido.
struct TrainingPlanRow: Codable {
    struct Author: Codable { let handle: String?; let name: String?; let avatar_url: String?; let gym_score: Int? }
    let id: UUID
    let user_id: UUID
    let title: String
    let when_text: String
    let place: String
    let spots: String
    let note: String?
    let created_at: String
    let cell_lat: Double?
    let cell_lon: Double?
    let author: Author?
}

/// Celda agregada del mapa de calor (sin identidades).
struct HeatCell: Codable, Identifiable {
    let cell_lat: Double
    let cell_lon: Double
    let users: Int
    var id: String { "\(cell_lat),\(cell_lon)" }
}

/// Fila de un entreno creado (plantilla). `exercises` se guarda como jsonb.
struct WorkoutRow: Codable {
    let id: String
    let user_id: String
    let name: String
    let description: String
    let block: String
    let exercises: [Exercise]

    init(_ w: WorkoutTemplate, userId: UUID) {
        id = w.id
        user_id = userId.uuidString.lowercased()
        name = w.name
        description = w.description
        block = w.block
        exercises = w.exercises
    }

    var asTemplate: WorkoutTemplate {
        WorkoutTemplate(id: id, name: name, description: description, block: block, exercises: exercises)
    }
}
