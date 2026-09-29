import SwiftUI
import MapKit
import CoreLocation

// MARK: - Dropdown styling helpers

private func fieldBox<Content: View>(_ focused: Bool, @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 8, content: content)
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 12).frame(height: 46).background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Brand.greenSoft : Brand.line, lineWidth: focused ? 1.5 : 1))
}

private func dropdown<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0, content: content)
        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Brand.line))
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        .padding(.top, 6)
        .transition(.opacity.combined(with: .move(edge: .top)))
}

// MARK: - País (local search over OS country list)

struct CountryField: View {
    let label: String
    let selected: String
    var onSelect: (String) -> Void
    @State private var query = ""
    @FocusState private var focused: Bool

    private var matches: [(name: String, flag: String)] {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return Array(allCountries.prefix(8)) }
        return Array(allCountries.filter { $0.name.localizedCaseInsensitiveContains(q) }.prefix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.t(label).uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            VStack(spacing: 0) {
                fieldBox(focused) {
                    Text(countryFlag(query.isEmpty ? selected : query))
                    TextField("Elegir país", text: $query).focused($focused)
                        .foregroundColor(Brand.ink).tint(Brand.ink)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Brand.soft) }
                    }
                }
                if focused, !matches.isEmpty {
                    dropdown {
                        ForEach(Array(matches.enumerated()), id: \.element.name) { idx, c in
                            Button { query = c.name; onSelect(c.name); focused = false } label: {
                                HStack { Text(c.flag); Text(c.name).foregroundColor(Brand.ink); Spacer() }
                                    .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 12).frame(height: 42)
                            }
                            if idx < matches.count - 1 { Divider() }
                        }
                    }
                }
            }
        }
        .onAppear { if query.isEmpty { query = selected } }
    }
}

// MARK: - Ciudad (live worldwide search via MapKit)

final class CityCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [(title: String, subtitle: String)] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        completer.pointOfInterestFilter = .excludingAll
    }

    /// Bias the search to the chosen country so cities from other countries
    /// don't show up.
    func setCountry(_ name: String) {
        guard !name.isEmpty else { return }
        CLGeocoder().geocodeAddressString(name) { [weak self] placemarks, _ in
            guard let coord = placemarks?.first?.location?.coordinate else { return }
            DispatchQueue.main.async {
                self?.completer.region = MKCoordinateRegion(
                    center: coord, span: MKCoordinateSpan(latitudeDelta: 11, longitudeDelta: 11))
            }
        }
    }

    func update(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { results = []; return }
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results.prefix(8).map { ($0.title, $0.subtitle) }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) { results = [] }
}

struct CitySearchField: View {
    let label: String
    let selected: String
    var country: String = ""
    var onSelect: (String) -> Void
    @StateObject private var completer = CityCompleter()
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.t(label).uppercased()).font(.caption2).fontWeight(.heavy).foregroundColor(Brand.muted)
            VStack(spacing: 0) {
                fieldBox(focused) {
                    Image(systemName: "magnifyingglass").font(.caption).foregroundColor(Brand.soft)
                    TextField("Busca tu ciudad", text: $query)
                        .focused($focused)
                        .foregroundColor(Brand.ink).tint(Brand.ink)
                        .onChange(of: query) { completer.update($0) }
                    if !query.isEmpty {
                        Button { query = ""; completer.update("") } label: { Image(systemName: "xmark.circle.fill").foregroundColor(Brand.soft) }
                    }
                }
                if focused, !completer.results.isEmpty {
                    dropdown {
                        ForEach(Array(completer.results.enumerated()), id: \.offset) { idx, r in
                            Button { onSelect(r.title); query = r.title; focused = false } label: {
                                HStack(spacing: 11) {
                                    ZStack {
                                        Circle().fill(Brand.greenSoft).frame(width: 32, height: 32)
                                        Image(systemName: "mappin").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "4f7a00"))
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(r.title).font(.system(size: 15, weight: .heavy)).foregroundColor(Brand.ink).lineLimit(1)
                                        if !r.subtitle.isEmpty { Text(r.subtitle).font(.caption2).foregroundColor(Brand.soft).lineLimit(1) }
                                    }
                                    Spacer()
                                }.padding(.horizontal, 12).frame(minHeight: 52).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            if idx < completer.results.count - 1 { Divider().padding(.leading, 54) }
                        }
                    }
                    .animation(.easeOut(duration: 0.18), value: completer.results.count)
                }
            }
        }
        .onAppear { if query.isEmpty { query = selected }; completer.setCountry(country) }
        .onChange(of: country) { newCountry in
            completer.setCountry(newCountry)
            query = ""; completer.update("")
            onSelect("")
        }
    }
}
