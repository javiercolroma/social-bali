import SwiftUI
import AVKit

/// Visor de fotos y vídeos del chat, como en WhatsApp:
///   · la foto CRECE desde su burbuja (matchedGeometryEffect) y vuelve a ella al cerrar;
///   · pellizcar o doble toque = zoom; con zoom, arrastrar mueve la foto;
///   · sin zoom: arrastrar abajo cierra (el fondo se desvanece), a los lados pasa a la
///     foto anterior/siguiente del chat.
struct ChatMediaViewer: View {
    let items: [ChatMessage]          // fotos y vídeos del chat, en orden
    @Binding var current: ChatMessage?
    let ns: Namespace.ID
    var senderName: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var drag: CGSize = .zero
    @State private var chrome = true

    private var index: Int { items.firstIndex { $0.id == current?.id } ?? 0 }
    private var dismissProgress: CGFloat { min(1, abs(drag.height) / 300) }

    var body: some View {
        ZStack {
            Color.black.opacity(1 - dismissProgress * 0.9).ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { chrome.toggle() } }

            if let m = current {
                media(m)
                    .scaleEffect(scale * (1 - dismissProgress * 0.25))
                    .offset(x: pan.width + (scale > 1 ? 0 : drag.width), y: pan.height + (scale > 1 ? 0 : drag.height))
                    .gesture(dragGesture)
                    .simultaneousGesture(zoomGesture)
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if scale > 1 { scale = 1; lastScale = 1; pan = .zero; lastPan = .zero }
                            else { scale = 2.5; lastScale = 2.5 }
                        }
                    }
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { chrome.toggle() } }
            }

            if chrome, let m = current {
                VStack {
                    HStack(spacing: 12) {
                        Button { close() } label: {
                            Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.fromMe ? L10n.t("You") : senderName).font(.system(size: 16, weight: .semibold))
                            Text(m.at, format: .dateTime.day().month().hour().minute()).font(.system(size: 12)).opacity(0.75)
                        }
                        .foregroundColor(.white)
                        Spacer()
                        if items.count > 1 {
                            Text("\(index + 1) / \(items.count)").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 8).padding(.top, 4)
                    .background(LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                    Spacer()
                    if !m.text.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(m.text).font(.system(size: 16)).foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18).padding(.vertical, 14)
                            .background(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
                    }
                }
                .opacity(1 - dismissProgress)
                .transition(.opacity)
            }
        }
        .statusBarHidden(!chrome)
    }

    @ViewBuilder
    private func media(_ m: ChatMessage) -> some View {
        if m.type == "video", let u = m.mediaURL.flatMap(URL.init(string:)) {
            VideoPlayer(player: AVPlayer(url: u))
                .aspectRatio(aspect(m), contentMode: .fit)
                .matchedGeometryEffect(id: m.id, in: ns)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            RemoteFill(url: m.mediaURL ?? m.posterURL ?? "")
                .aspectRatio(aspect(m), contentMode: .fit)
                .matchedGeometryEffect(id: m.id, in: ns)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func aspect(_ m: ChatMessage) -> CGFloat {
        guard let w = m.w, let h = m.h, w > 0, h > 0 else { return 1 }
        return CGFloat(w) / CGFloat(h)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { v in scale = min(4, max(1, lastScale * v)) }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.02 { withAnimation(.spring()) { scale = 1; lastScale = 1; pan = .zero; lastPan = .zero } }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                if scale > 1 { pan = CGSize(width: lastPan.width + v.translation.width, height: lastPan.height + v.translation.height) }
                else { drag = v.translation }
            }
            .onEnded { v in
                if scale > 1 { lastPan = pan; return }
                let t = v.translation
                if abs(t.height) > 120 && abs(t.height) > abs(t.width) {
                    close()
                } else if abs(t.width) > 80 && abs(t.width) > abs(t.height) {
                    let next = index + (t.width < 0 ? 1 : -1)
                    if items.indices.contains(next) {
                        withAnimation(.easeInOut(duration: 0.22)) { drag = .zero }
                        current = items[next]
                        FX.selection()
                    } else {
                        withAnimation(.spring()) { drag = .zero }
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drag = .zero }
                }
            }
    }

    private func close() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            scale = 1; pan = .zero; drag = .zero
            current = nil
        }
    }
}
