import Foundation

/// Configuración del backend (Supabase).
///
/// ─── CÓMO ACTIVARLO ─────────────────────────────────────────────────────────
/// Ver `backend/README.md`. En resumen:
/// 1. Crea un proyecto en https://supabase.com
/// 2. Project Settings → API → copia **Project URL** y **anon public key**.
/// 3. Pégalos aquí abajo.
/// 4. Ejecuta las migraciones de `backend/supabase/migrations/` en el SQL Editor.
///
/// Mientras estén vacíos, `Backend.isConfigured == false` y la app funciona 100%
/// en local (UserDefaults), sin tocar Supabase.
enum BackendConfig {
    /// p. ej. "https://xxxxxxxx.supabase.co"
    static let supabaseURL = ""
    /// La clave **anon public** (NO la service_role).
    static let supabaseAnonKey = ""

    static var isConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty && URL(string: supabaseURL) != nil
    }
}
