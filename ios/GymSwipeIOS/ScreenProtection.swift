import SwiftUI
import UIKit

/// Capturas de pantalla bloqueadas (en la práctica: la captura sale en negro).
///
/// iOS no tiene una API oficial para impedir capturas. Se usa el mismo truco que apps
/// como Snapchat o las de bancos: la capa de la ventana se mete dentro de la capa
/// «segura» de un campo de contraseña, que el sistema excluye de capturas y grabaciones.
/// Al cubrir la VENTANA entera, también quedan protegidas las hojas y pantallas
/// presentadas encima (perfil, visor de fotos, Momentos…).
/// Límites: no evita una foto hecha con otro móvil, y al no ser API oficial podría dejar
/// de funcionar en una versión futura de iOS.
@MainActor
enum ScreenProtection {
    private static var field: UITextField?

    static func enable() {
        guard field == nil,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow) else { return }
        let f = UITextField()
        f.isSecureTextEntry = true
        f.isUserInteractionEnabled = false
        // Del tamaño de la ventana y en su origen: la capa segura debe coincidir con ella.
        f.frame = window.bounds
        f.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(f)
        f.layoutIfNeeded()
        // La ventana pasa a vivir dentro de la capa segura del campo.
        window.layer.superlayer?.addSublayer(f.layer)
        guard let secure = f.layer.sublayers?.last else { f.removeFromSuperview(); return }
        secure.frame = window.bounds
        secure.addSublayer(window.layer)
        window.layer.frame = window.bounds
        field = f
    }
}

/// Tapa con el logo mientras se graba la pantalla, y aviso si alguien hace una captura.
struct CaptureGuard: ViewModifier {
    @State private var recording = UIScreen.main.isCaptured
    @State private var warn = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if recording { AppSwitcherCover().transition(.opacity).zIndex(200) }
            }
            .overlay(alignment: .top) {
                if warn {
                    Label("Screenshots are disabled in Bali Circle", systemImage: "eye.slash")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.black.opacity(0.85)).clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(201)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { recording = UIScreen.main.isCaptured }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
                withAnimation(.spring()) { warn = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { warn = false } }
            }
            .onAppear {
                // Cuando la ventana ya existe.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { ScreenProtection.enable() }
            }
    }
}

extension View {
    func captureGuard() -> some View { modifier(CaptureGuard()) }
}
