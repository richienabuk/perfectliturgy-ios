import SwiftData
import SwiftUI

struct DownloadsView: View {
    @Environment(InstalledPacks.self) private var packs
    @Environment(AppSession.self) private var session
    @Environment(AppNavigation.self) private var navigation
    @Environment(ReadingsPreferences.self) private var readings
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide
    @Environment(\.modelContext) private var modelContext

    @State private var sections: [PackSection]

    init() {
        let rows = PackFiles.rowsForDisplay(root: DevotionLibrary.applicationSupport)
        _sections = State(initialValue: PackSections.group(rows))
    }
    @State private var downloading: Set<String> = []
    @State private var notes: [String: String] = [:]
    @State private var showsSignIn = false
    @State private var openAccount = false

    private var suggestedID: String? {
        let packs = sections.flatMap(\.packs)
        let region = Locale.current.region?.identifier
        return PackLocale.recommendedCalendar(in: packs, region: region)?.packId
    }

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.horizontal, isWide ? 28 : 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: isWide ? 840 : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background.color)
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await reload()
        }
        .sheet(isPresented: $showsSignIn, onDismiss: openAccountIfNeeded) {
            signInSheet
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Downloads")
                .font(AppFont.heading(size: 40))
                .foregroundStyle(palette.foreground.color)
                .tracking(40 * AppFont.headingTrackingFactor)
                .accessibilityAddTraits(.isHeader)
            Text("Manage languages and content packs.")
                .font(AppFont.body())
                .foregroundStyle(palette.mutedForeground.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionView(_ section: PackSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.title.uppercased())
                .font(AppFont.eyebrow())
                .tracking(AppFont.eyebrowTracking)
                .foregroundStyle(palette.mutedForeground.color)
                .padding(.top, 4)
            ForEach(section.packs) { pack in
                row(pack)
            }
        }
    }

    private func row(_ pack: PackRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pack.displayName)
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                        .multilineTextAlignment(.leading)
                    Text(detail(for: pack))
                        .font(AppFont.interface(size: 13))
                        .foregroundStyle(palette.mutedForeground.color)
                    if pack.packId == suggestedID {
                        Text("Suggested for this device.")
                            .font(AppFont.interface(size: 13))
                            .foregroundStyle(palette.emphasis.color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                action(for: pack)
            }
            if let note = notes[pack.packId] {
                Text(note)
                    .font(AppFont.interface(size: 13))
                    .foregroundStyle(palette.emphasis.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.border.color)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func action(for pack: PackRecord) -> some View {
        if downloading.contains(pack.packId) {
            EmptyView()
        } else if packs.contains(pack.packId) {
            rowButton("Remove", kind: .outline) {
                remove(pack)
            }
        } else {
            rowButton("Download", kind: .primary) {
                Task { await download(pack) }
            }
        }
    }

    private func rowButton(_ title: String, kind: PLButton.Kind, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.interface(size: 15, weight: .semibold))
                .foregroundStyle(kind == .primary ? palette.primaryForeground.color : palette.primary.color)
                .frame(minWidth: 104, minHeight: ControlMetrics.minimumHeight)
                .padding(.horizontal, 12)
                .background(
                    kind == .primary ? palette.primary.color : Color.clear,
                    in: RoundedRectangle(cornerRadius: Radius.md)
                )
                .overlay {
                    if kind == .outline {
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(palette.border.color, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
    }

    private func detail(for pack: PackRecord) -> String {
        var parts: [String] = []
        if let size = pack.size {
            parts.append(PackSize.text(size))
        }
        if downloading.contains(pack.packId) {
            parts.append("Downloading")
        } else if packs.contains(pack.packId) {
            parts.append("Installed")
        } else {
            parts.append("Not installed")
        }
        if pack.type == "readings",
           let through = pack.metadata?.coverageThrough,
           !through.isEmpty {
            parts.append("Readings available through \(PackCoverage.text(through)).")
        }
        return parts.joined(separator: " · ")
    }

    private var signInSheet: some View {
        SignInSheet {
            openAccount = true
        }
    }

    private func reload() async {
        let rows = await PackInstaller.catalog(client: client, supportRoot: DevotionLibrary.applicationSupport)
        sections = PackSections.group(rows)
    }

    private func download(_ pack: PackRecord) async {
        notes[pack.packId] = nil
        if pack.requiresSignIn, !session.isSignedIn {
            showsSignIn = true
            return
        }
        downloading.insert(pack.packId)
        let result = await PackInstaller.install(
            pack,
            client: client,
            context: modelContext,
            packs: packs,
            supportRoot: DevotionLibrary.applicationSupport,
            defaults: .standard
        )
        downloading.remove(pack.packId)
        switch result {
        case .installed:
            notes[pack.packId] = nil
            if pack.type == "calendar" {
                readings.noteCalendarInstalled(pack.packId, installedIDs: packs.ids)
            }
        case .needsSignIn:
            showsSignIn = true
        case .unavailable:
            notes[pack.packId] = "This pack is not available yet."
        case .connection:
            notes[pack.packId] = "Check the connection and try again."
        }
    }

    private func remove(_ pack: PackRecord) {
        notes[pack.packId] = nil
        Task {
            try? await PackInstaller.remove(
                pack,
                context: modelContext,
                packs: packs,
                supportRoot: DevotionLibrary.applicationSupport,
                defaults: .standard
            )
            if pack.type == "calendar" {
                readings.noteCalendarRemoved(pack.packId, remainingIDs: packs.ids)
            }
        }
    }

    private var client: PackClient {
        PackClient(
            transport: LivePackTransport(),
            apiBase: ServiceOrigin.apiBaseURL,
            token: session.token
        )
    }

    private func openAccountIfNeeded() {
        guard openAccount else { return }
        openAccount = false
        navigation.path.append(AppRoute.account)
    }
}

private struct SignInSheet: View {
    let openAccount: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("Sign in")
                    .font(AppFont.heading(size: 32))
                    .foregroundStyle(palette.foreground.color)
                    .tracking(32 * AppFont.headingTrackingFactor)
                Spacer(minLength: 8)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                        .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel("Close")
            }
            Text("Sign in to download this pack.")
                .font(AppFont.interface(size: 16))
                .foregroundStyle(palette.mutedForeground.color)
                .fixedSize(horizontal: false, vertical: true)
            PLButton(title: "Account") {
                openAccount()
                dismiss()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background.color)
        .fittedBottomSheet(key: "downloads.signIn", estimate: 280)
    }
}
