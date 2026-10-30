import SwiftUI

// MARK: - Puerta de entrada (0039): «Apply to join. Not everyone gets in.»
//
// Tras el registro, la solicitud queda PENDIENTE hasta que un admin la aprueba a mano
// (o se canjea un código de invitación). Mientras tanto, la app entera es esta pantalla.

struct MembershipGate: View {
    @EnvironmentObject var store: AppStore
    let membership: Membership
    @State private var code = ""
    @State private var redeeming = false
    @State private var codeError: String?
    @State private var showCode = false
    @State private var editing = false
    @State private var settings = false
    @State private var reapplying = false

    private var declined: Bool { membership.status == "declined" }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Su foto principal, como recordatorio de que el perfil ya está hecho.
                Group {
                    if let m = store.profile.media?.first { MediaView(item: m, autoplay: false) }
                    else if let d = store.account?.photoData, let img = UIImage(data: d) {
                        Color.clear.overlay(Image(uiImage: img).resizable().scaledToFill())
                    } else { Brand.sand }
                }
                .frame(width: 132, height: 132).clipShape(Circle())
                .overlay(Circle().stroke(declined ? AnyShapeStyle(Brand.line) : AnyShapeStyle(MomentRing.gradient), lineWidth: 2.5).padding(-6))
                .padding(.top, 48)

                VStack(spacing: 10) {
                    Text("BALI CIRCLE").font(.system(size: 11, weight: .bold)).tracking(2.4).foregroundColor(Brand.bronze)
                    Text(declined ? "We couldn't make room this time" : "You're on the list")
                        .font(.display(30)).foregroundColor(Brand.ink).multilineTextAlignment(.center)
                    Text(declined
                         ? "Bali Circle is a small, curated community. Complete your profile — real photos, your sports, a line about you — and apply again."
                         : "Every profile is reviewed by hand so the people inside are worth meeting. It usually takes less than 24 hours. We'll open your circle the moment you're in.")
                        .font(.system(size: 16)).foregroundColor(Brand.muted).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 10) {
                    if declined {
                        Button { FX.tap(); editing = true } label: { Text("Edit my profile") }.buttonStyle(PrimaryButtonStyle())
                        Button { Task { await reapply() } } label: {
                            if reapplying { ProgressView().tint(Brand.ink) } else { Text("Apply again") }
                        }
                        .buttonStyle(.plain).font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink).frame(height: 40)
                    } else {
                        Button { FX.tap(); store.loadMembership() } label: { Text("Check my status") }.buttonStyle(PrimaryButtonStyle())
                        Button { FX.tap(); editing = true } label: {
                            Text("Review my profile").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                        }.buttonStyle(.plain).frame(height: 40)
                    }

                    // Invitación: entra directamente.
                    if showCode {
                        VStack(spacing: 8) {
                            TextField("Invite code", text: $code)
                                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                                .font(.system(size: 17, weight: .semibold)).multilineTextAlignment(.center)
                                .padding(.horizontal, 14).frame(height: 50).background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.line))
                            Button { Task { await redeem() } } label: { if redeeming { ProgressView().tint(Brand.onAccent) } else { Text("Use invite") } }
                                .buttonStyle(PrimaryButtonStyle(enabled: !code.trimmingCharacters(in: .whitespaces).isEmpty))
                                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || redeeming)
                            if let codeError { Text(codeError).font(.footnote).foregroundColor(Brand.redText) }
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        Button { withAnimation { showCode = true } } label: {
                            Text("Have an invite code?").font(.system(size: 14, weight: .medium)).foregroundColor(Brand.muted).underline()
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 28)

                Button { FX.tap(); settings = true } label: {
                    Text("Settings").font(.system(size: 13, weight: .medium)).foregroundColor(Brand.soft)
                }
                .padding(.top, 10).padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Brand.bg.ignoresSafeArea())
        .refreshable { store.loadMembership() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in store.loadMembership() }
        .task {
            // Mientras está pendiente, se comprueba cada minuto: al aprobarlo, entra solo.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                store.loadMembership()
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { EditProfileView() }.environmentObject(store) }
        .sheet(isPresented: $settings) { SettingsView().environmentObject(store) }
    }

    private func redeem() async {
        redeeming = true; codeError = nil
        let ok = await Backend.shared.redeemAccessCode(code.trimmingCharacters(in: .whitespaces))
        redeeming = false
        if ok { FX.success(); store.loadMembership() } else { FX.warning(); codeError = L10n.t("That code isn't valid.") }
    }

    private func reapply() async {
        reapplying = true
        await Backend.shared.reapply()
        store.syncProfileToBackend()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        store.loadMembership()
        reapplying = false
    }
}

// MARK: - Invitar amigos (código personal, 3 usos)

struct InviteCard: View {
    let code: String
    let left: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INVITE A FRIEND").font(.system(size: 11, weight: .bold)).tracking(1.4).foregroundColor(Brand.muted)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(code).font(.system(size: 22, weight: .semibold, design: .monospaced)).foregroundColor(Brand.ink)
                    Text(left == 1 ? L10n.t("1 invite left") : String(format: L10n.t("%lld invites left"), left))
                        .font(.system(size: 13)).foregroundColor(Brand.muted)
                }
                Spacer()
                if left > 0 {
                    ShareLink(item: String(format: L10n.t("You're invited to Bali Circle — a private circle for active people in Bali. Download the app and use my invite code %@ to skip the waitlist. %@"), code, "https://balicircle.vercel.app")) {
                        Label("Share", systemImage: "square.and.arrow.up").font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Brand.onAccent).padding(.horizontal, 14).frame(height: 40)
                            .background(Brand.accent).clipShape(Capsule())
                    }
                }
            }
            Text("Friends who use your code skip the review. Invite people you'd actually want to train or surf with.")
                .font(.footnote).foregroundColor(Brand.soft)
        }
        .padding(16)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Brand.line))
    }
}

// MARK: - Admin: solicitudes pendientes

struct AdminApplicationsRow: View {
    let count: Int
    @State private var open = false

    var body: some View {
        Button { FX.tap(); open = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.badge.clock").font(.system(size: 18, weight: .medium)).foregroundColor(Brand.bronze)
                    .frame(width: 40, height: 40).background(Brand.sand).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Applications").font(.system(size: 16, weight: .semibold)).foregroundColor(Brand.ink)
                    Text(count == 0 ? L10n.t("Nothing to review") : (count == 1 ? L10n.t("1 person waiting") : String(format: L10n.t("%lld people waiting"), count)))
                        .font(.system(size: 13)).foregroundColor(Brand.muted)
                }
                Spacer()
                if count > 0 {
                    Text("\(count)").font(.system(size: 12, weight: .bold)).foregroundColor(Brand.onAccent)
                        .padding(.horizontal, 8).frame(minWidth: 24, minHeight: 24).background(Brand.accent).clipShape(Capsule())
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(Brand.soft)
            }
            .padding(14)
            .background(Brand.panel)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Brand.line))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $open) { ApplicationsView() }
    }
}

/// Lista de solicitudes: la tarjeta entera para decidir con criterio (lifestyle, perfil
/// real y completo, encaje con la comunidad — nunca el físico). Aprobar o declinar.
struct ApplicationsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var apps: [ProfileRow] = []
    @State private var loaded = false
    @State private var busy: Set<String> = []
    @State private var openProfile: ProfileRow?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if loaded && apps.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.seal").font(.system(size: 30, weight: .light)).foregroundColor(Brand.soft)
                            Text("All caught up").font(.display(22)).foregroundColor(Brand.ink)
                            Text("New applications will show up here.").font(.footnote).foregroundColor(Brand.muted)
                        }.padding(.top, 80)
                    }
                    ForEach(apps) { p in card(p) }
                }
                .padding(16)
            }
            .background(Brand.bg)
            .navigationTitle("Applications").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $openProfile) { ClubProfileView(personId: $0.id.uuidString.lowercased(), initial: $0).environmentObject(store) }
        }
    }

    private func load() async {
        apps = await Backend.shared.pendingApplications()
        loaded = true
    }

    private func card(_ p: ProfileRow) -> some View {
        let club = p.club
        let id = p.id.uuidString.lowercased()
        return VStack(alignment: .leading, spacing: 12) {
            Button { openProfile = p } label: {
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if let m = p.media?.first { RemoteFill(url: m.url) } else if let a = p.avatar_url { RemoteFill(url: a) } else { Brand.sand }
                    }
                    .frame(width: 84, height: 105).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(p.age.map { "\(p.name ?? ""), \($0)" } ?? (p.name ?? "")).font(.system(size: 17, weight: .semibold)).foregroundColor(Brand.ink)
                            if let c = club.homeCountry, !c.isEmpty { Text(countryFlag(c)) }
                        }
                        Text([club.area?.label, club.stay?.headline].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 13)).foregroundColor(Brand.muted)
                        if !club.sportList.isEmpty {
                            Text(club.sportList.map { "\($0.emoji) \($0.label)" }.joined(separator: "  ")).font(.system(size: 13)).foregroundColor(Brand.ink).lineLimit(1)
                        }
                        if let b = club.trimmedBio {
                            Text("“\(b)”").font(.system(size: 14)).foregroundColor(Brand.ink).lineLimit(2)
                        }
                        Text(String(format: L10n.t("%lld photos · applied %@"), (p.media ?? []).count, relativeTime(BackendDate.parse(p.applied_at ?? "") ?? Date())))
                            .font(.system(size: 12)).foregroundColor(Brand.soft)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            HStack(spacing: 10) {
                Button { Task { await decide(id, true) } } label: {
                    Label("Approve", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(busy.contains(id))
                Button { Task { await decide(id, false) } } label: {
                    Text("Decline").font(.system(size: 15, weight: .semibold)).foregroundColor(Brand.ink)
                        .frame(width: 100, height: 54).background(Brand.chip).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain).disabled(busy.contains(id))
            }
        }
        .padding(14)
        .background(Brand.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Brand.line))
    }

    private func decide(_ id: String, _ approve: Bool) async {
        busy.insert(id)
        if await Backend.shared.reviewApplication(id, approve: approve) {
            approve ? FX.success() : FX.tap()
            withAnimation { apps.removeAll { $0.id.uuidString.lowercased() == id } }
            store.loadMembership()
        } else { FX.warning() }
        busy.remove(id)
    }
}
