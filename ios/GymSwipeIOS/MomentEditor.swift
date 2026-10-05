import SwiftUI
import Photos

// MARK: - Editor de Momentos, como una historia de Instagram
//
// Lienzo vertical 9:16: la foto se MUEVE y se AMPLÍA con los dedos (y gira con dos),
// y se puede añadir texto («Aa») que se arrastra y se escala. Al terminar se «hornea»
// todo en una imagen 1080×1920 que es la que se sube. Los vídeos pasan tal cual
// (en el visor se recortan para llenar la pantalla sin deformarse).

struct StoryText: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var color: Color
    var offset: CGSize = .zero
    var scale: CGFloat = 1
}

struct StoryEditor: View {
    let image: UIImage
    var onDone: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var angle: Angle = .zero
    @State private var lastAngle: Angle = .zero
    @State private var texts: [StoryText] = []
    @State private var editing: UUID?
    @State private var draft = ""
    @State private var draftColor: Color = .white
    @FocusState private var typing: Bool

    private static let colors: [Color] = [.white, .black, Color(hex: "e9e0d0"), Color(hex: "c98a6b"), Color(hex: "8aa07e")]

    var body: some View {
        GeometryReader { geo in
            let canvas = canvasSize(in: geo.size)
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 14) {
                    // Barra superior: cancelar · texto · listo
                    HStack {
                        Button { onCancel() } label: { circle("xmark") }
                        Spacer()
                        Button { startText() } label: {
                            Text("Aa").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                .frame(width: 42, height: 42).background(.white.opacity(0.18)).clipShape(Circle())
                        }
                        Button { finish(canvas) } label: {
                            Text("Next").font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                                .padding(.horizontal, 16).frame(height: 42).background(Color.white).clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)

                    storyCanvas(canvas, editingMode: true)
                        .frame(width: canvas.width, height: canvas.height)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .gesture(photoGesture)

                    Text("Drag to move · pinch to zoom · two fingers to rotate")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)

                if editing != nil { textEditorOverlay }
            }
        }
        .statusBarHidden()
    }

    private func canvasSize(in size: CGSize) -> CGSize {
        let h = min(size.height - 140, (size.width - 24) * 16 / 9)
        return CGSize(width: h * 9 / 16, height: h)
    }

    /// El lienzo: foto (movible) + textos. Se reutiliza para «hornear» la imagen final.
    private func storyCanvas(_ size: CGSize, editingMode: Bool) -> some View {
        ZStack {
            Color.black
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .rotationEffect(angle)
                .offset(offset)
            ForEach($texts) { $t in
                Text(t.text)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(t.color)
                    .multilineTextAlignment(.center)
                    .shadow(color: t.color == .white ? .black.opacity(0.35) : .clear, radius: 2)
                    .scaleEffect(t.scale)
                    .offset(t.offset)
                    .opacity(editing == t.id ? 0 : 1)
                    .gesture(editingMode ? textGesture($t) : nil)
                    .onTapGesture { if editingMode { edit(t) } }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var photoGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { v in offset = CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height) }
                .onEnded { _ in lastOffset = offset },
            SimultaneousGesture(
                MagnificationGesture()
                    .onChanged { v in scale = max(0.5, min(5, lastScale * v)) }
                    .onEnded { _ in lastScale = scale },
                RotationGesture()
                    .onChanged { a in angle = lastAngle + a }
                    .onEnded { _ in lastAngle = angle }
            )
        )
    }

    private func textGesture(_ t: Binding<StoryText>) -> some Gesture {
        SimultaneousGesture(
            DragGesture().onChanged { v in t.wrappedValue.offset = v.translation }
                .onEnded { v in t.wrappedValue.offset = v.translation },
            MagnificationGesture().onChanged { v in t.wrappedValue.scale = max(0.5, min(4, v)) }
        )
    }

    // MARK: Texto

    private var textEditorOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { commitText() }
            VStack {
                HStack {
                    Spacer()
                    Button { commitText() } label: {
                        Text("Done").font(.system(size: 16, weight: .semibold)).foregroundColor(.white).padding(14)
                    }
                }
                Spacer()
                TextField("", text: $draft, axis: .vertical)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(draftColor)
                    .multilineTextAlignment(.center)
                    .focused($typing)
                    .padding(.horizontal, 30)
                Spacer()
                HStack(spacing: 12) {
                    ForEach(Self.colors, id: \.self) { c in
                        Button { draftColor = c } label: {
                            Circle().fill(c).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.white, lineWidth: draftColor == c ? 3 : 1.5))
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .onAppear { typing = true }
    }

    private func startText() {
        let t = StoryText(text: "", color: .white)
        texts.append(t)
        draft = ""; draftColor = .white
        editing = t.id
    }

    private func edit(_ t: StoryText) {
        draft = t.text; draftColor = t.color; editing = t.id
    }

    private func commitText() {
        guard let id = editing, let i = texts.firstIndex(where: { $0.id == id }) else { editing = nil; return }
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { texts.remove(at: i) } else { texts[i].text = clean; texts[i].color = draftColor }
        editing = nil; typing = false
    }

    private func circle(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            .frame(width: 42, height: 42).background(.white.opacity(0.18)).clipShape(Circle())
    }

    /// «Hornea» el lienzo en una imagen 1080×1920.
    private func finish(_ canvas: CGSize) {
        commitText()
        let renderer = ImageRenderer(content: storyCanvas(canvas, editingMode: false))
        renderer.scale = 1080 / canvas.width
        if let img = renderer.uiImage { onDone(img) } else { onDone(image) }
    }
}

/// Carga la imagen a tamaño completo de lo elegido (galería o cámara).
enum PendingImageLoader {
    static func image(for m: PendingMedia) async -> UIImage? {
        switch m {
        case .image(let i): return i
        case .video: return nil
        case .asset(let a):
            guard a.mediaType == .image else { return nil }
            return await withCheckedContinuation { c in
                let o = PHImageRequestOptions(); o.isNetworkAccessAllowed = true; o.deliveryMode = .highQualityFormat
                PHImageManager.default().requestImage(for: a, targetSize: CGSize(width: 2000, height: 2000),
                                                      contentMode: .aspectFit, options: o) { img, info in
                    if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                    c.resume(returning: img)
                }
            }
        }
    }
}
