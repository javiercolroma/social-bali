import SwiftUI
import PhotosUI

private let editSize: CGFloat = 240

/// Avatar for "me": shows the account photo (with stored scale/offset) or a fallback emoji.
struct MeAvatar: View {
    let account: Account?
    var size: CGFloat = 42

    var body: some View {
        if let data = account?.photoData, let ui = UIImage(data: data) {
            let scale = CGFloat(account?.photoScale ?? 1)
            let ratio = size / editSize
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .scaleEffect(scale)
                .offset(x: CGFloat(account?.photoOffsetX ?? 0) * ratio,
                        y: CGFloat(account?.photoOffsetY ?? 0) * ratio)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Avatar(emoji: "🙂", size: size)
        }
    }
}

/// Comprime una imagen para guardar/subir: reescala a un lado máximo razonable y
/// re-codifica a JPEG. Sin esto, una foto del carrete (HEIC de 10+ MB) acabaría entera
/// en UserDefaults (persistencia local) y en Storage (subida lenta y cara).
func compressedImageData(_ data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.72) -> Data {
    guard let img = UIImage(data: data) else { return data }
    let maxSide = max(img.size.width, img.size.height)
    var out = img
    if maxSide > maxDimension {
        let k = maxDimension / maxSide
        let newSize = CGSize(width: img.size.width * k, height: img.size.height * k)
        out = UIGraphicsImageRenderer(size: newSize).image { _ in
            img.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    let jpeg = out.jpegData(compressionQuality: quality) ?? data
    return jpeg.count < data.count ? jpeg : data   // nunca "comprimir" a algo más grande
}

/// Picks an image and returns its Data via the callback.
struct PhotoPickerLabel<Label: View>: View {
    @Binding var item: PhotosPickerItem?
    var onPicked: (Data) -> Void
    @ViewBuilder var label: Label

    var body: some View {
        PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) { label }
            .onChange(of: item) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        // Comprimir AQUÍ cubre todos los pickers de la app (avatar y foto de entreno).
                        let small = compressedImageData(data)
                        await MainActor.run { onPicked(small) }
                    }
                }
            }
    }
}

/// Drag + pinch editor for the chosen photo.
struct PhotoEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let data: Data

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Arrastra y pellizca para ajustar").font(.footnote).foregroundColor(Brand.muted)
                if let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: editSize, height: editSize)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Brand.line, lineWidth: 2))
                        .contentShape(Circle())
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { scale = max(1, min(4, lastScale * $0)) }
                                    .onEnded { _ in lastScale = scale },
                                DragGesture()
                                    .onChanged { offset = CGSize(width: lastOffset.width + $0.translation.width,
                                                                 height: lastOffset.height + $0.translation.height) }
                                    .onEnded { _ in lastOffset = offset }
                            )
                        )
                }
                Button {
                    var acc = store.account ?? Account(name: "", handle: "")
                    acc.photoData = data
                    acc.photoScale = Double(scale)
                    acc.photoOffsetX = Double(offset.width)
                    acc.photoOffsetY = Double(offset.height)
                    store.saveAccount(acc)
                    dismiss()
                } label: { Text("Guardar foto") }.buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding(20)
            .background(Brand.bg)
            .navigationTitle("Ajustar foto").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                scale = CGFloat(store.account?.photoScale ?? 1); lastScale = scale
                offset = CGSize(width: CGFloat(store.account?.photoOffsetX ?? 0), height: CGFloat(store.account?.photoOffsetY ?? 0))
                lastOffset = offset
            }
        }
    }
}
