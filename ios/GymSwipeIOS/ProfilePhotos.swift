import SwiftUI
import PhotosUI

// MARK: - Fotos de la persona (PRODUCT.md, Fase 3 · migración 0027)
//
// Que se VEA quién hay detrás sin convertirlo en un catálogo de fotos posadas: la foto
// de perfil manda, y además hasta 4 fotos opcionales «haciendo lo que te gusta» y las de
// sus últimos entrenos públicos. Se piden con una invitación amable, nunca como requisito.

/// Imagen remota que rellena su marco (sin deformar) con un fondo mientras carga.
struct RemoteFill: View {
    let url: String
    var body: some View {
        Color.clear.overlay(
            AsyncImage(url: URL(string: url)) { phase in
                if let img = phase.image { img.resizable().scaledToFill() }
                else { Brand.chip }
            }
        )
        .clipped()
    }
}

/// Carrusel de la tarjeta de Descubrir: foto de perfil + fotos + momentos, con puntos.
struct PhotoPager<Placeholder: View>: View {
    let urls: [String]
    @ViewBuilder var placeholder: Placeholder
    @State private var index = 0

    var body: some View {
        if urls.isEmpty {
            placeholder
        } else {
            ZStack(alignment: .top) {
                TabView(selection: $index) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { i, u in RemoteFill(url: u).tag(i) }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                if urls.count > 1 {
                    // Barritas arriba (como las historias): se ve que hay más sin tapar la cara.
                    HStack(spacing: 4) {
                        ForEach(0..<urls.count, id: \.self) { i in
                            Capsule().fill(i == index ? Color.white : Color.white.opacity(0.4)).frame(height: 3)
                        }
                    }
                    .shadow(color: .black.opacity(0.35), radius: 2)   // se ven también sobre fotos claras
                    .padding(.horizontal, 12).padding(.top, 10)
                }
            }
        }
    }
}

/// Tira horizontal de fotos para el perfil (propio y ajeno).
struct PhotoStrip: View {
    let urls: [String]
    var body: some View {
        if !urls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(urls, id: \.self) { u in
                        RemoteFill(url: u).frame(width: 150, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }
}

/// «¿Quieres compartir alguna foto haciendo lo que te gusta?» — invitación, no requisito.
struct PhotosInviteCard: View {
    var onAdd: () -> Void
    var body: some View {
        PanelCard {
            HStack(alignment: .top, spacing: 12) {
                Text("📸").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share a photo doing what you love").font(.system(size: 16, weight: .heavy)).foregroundColor(Brand.ink)
                    Text("Surfing, on the mat, at the summit… No posing required. It helps people see who you are.")
                        .font(.footnote).foregroundColor(Brand.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            Button { FX.tap(); onAdd() } label: { Label("Add photos", systemImage: "plus") }
                .buttonStyle(PrimaryButtonStyle())
        }
    }
}

/// Editor: 4 huecos. Tocar uno vacío abre la galería; tocar una foto deja quitarla.
struct ActivityPhotosEditor: View {
    @EnvironmentObject var store: AppStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var uploading = false
    @State private var failed = false
    @State private var toRemove: String?

    private var photos: [String] { store.profile.photos ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHOTOS").font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            Text("Up to 4 photos doing what you love. Optional.").font(.caption).foregroundColor(Brand.soft)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    if i < photos.count {
                        Button { toRemove = photos[i] } label: {
                            RemoteFill(url: photos[i]).frame(maxWidth: .infinity).aspectRatio(3 / 4, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }.buttonStyle(.plain)
                    } else if i == photos.count {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            slot(icon: uploading ? nil : "plus")
                        }.disabled(uploading || !BackendConfig.isConfigured)
                    } else {
                        slot(icon: nil).opacity(0.5)
                    }
                }
            }
            if failed { Text("Couldn't upload the photo. Try again.").font(.caption).foregroundColor(Brand.redText) }
        }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task { await add(item) }
        }
        .confirmationDialog("Remove this photo?", isPresented: Binding(get: { toRemove != nil }, set: { if !$0 { toRemove = nil } }),
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) { if let u = toRemove { remove(u) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func slot(icon: String?) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.surface)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Brand.line))
            .overlay { if let icon { Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundColor(Brand.soft) } else if uploading { ProgressView() } }
            .frame(maxWidth: .infinity).aspectRatio(3 / 4, contentMode: .fit)
    }

    private func add(_ item: PhotosPickerItem) async {
        uploading = true; failed = false
        defer { uploading = false; pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { failed = true; return }
        do {
            let url = try await Backend.shared.uploadActivityPhoto(data)
            store.profile.photos = Array((photos + [url]).prefix(4))
            store.persist()
            store.syncProfileToBackend()
            FX.success()
        } catch {
            print("[Photos] subida falló:", error)
            failed = true
        }
    }

    private func remove(_ url: String) {
        store.profile.photos = photos.filter { $0 != url }
        store.persist()
        store.syncProfileToBackend()
        Task { await Backend.shared.deleteActivityPhoto(url) }
        toRemove = nil
    }
}
