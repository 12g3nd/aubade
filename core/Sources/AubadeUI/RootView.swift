import SwiftUI
import AubadeCore

/// What the app shows, whichever state the morning is in.
public struct AubadeRootView: View {
    @ObservedObject private var store: MorningStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingSettings = false

    public init(store: MorningStore) {
        self.store = store
    }

    public var body: some View {
        let theme = Theme.forScheme(colorScheme)
        ZStack {
            theme.palette.newsprint.ignoresSafeArea()
            content
        }
        .environment(\.theme, theme)
        .task { await store.open() }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store, canDismiss: true, isPresented: $showingSettings)
                .environment(\.theme, theme)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .needsSetup:
            // First run: nothing behind this, so there is nothing to dismiss to.
            SettingsView(store: store, canDismiss: false, isPresented: .constant(true))

        case .ready(let presentation):
            EditionView(
                presentation: presentation,
                onAction: { id, action in store.record(action, for: id) },
                onOpenSettings: { showingSettings = true }
            )

        case .preparing(let previous):
            if let previous {
                VStack(spacing: 0) {
                    // Clearly dated, so yesterday's edition is never mistaken for today's.
                    PreviousEditionBanner(presentation: previous)
                    EditionView(
                        presentation: previous,
                        onOpenSettings: { showingSettings = true }
                    )
                }
            } else {
                PreparingView()
            }
        }
    }
}

/// Says plainly which morning you are looking at while today's is assembled.
struct PreviousEditionBanner: View {
    let presentation: EditionPresentation
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.6)
            Text("Preparing today. This is \(presentation.folioDate).".uppercased())
                .font(theme.type.folio)
                .tracking(1.1)
                .foregroundStyle(theme.palette.inkMuted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 19)
        .padding(.vertical, 8)
        .background(theme.palette.rule.opacity(0.4))
    }
}

struct PreparingView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Text("Aubade")
                .font(theme.type.masthead)
                .foregroundStyle(theme.palette.ink)
            Text("Preparing this morning's edition".uppercased())
                .font(theme.type.folio)
                .tracking(1.4)
                .foregroundStyle(theme.palette.inkMuted)
            ProgressView().padding(.top, 4)
        }
    }
}

/// Connecting Quercus, and changing your mind later.
///
/// Reachable from the colophon at the end of every edition, not only on first run - a
/// token that is revoked or pasted wrong has to be fixable, and an app you cannot get back
/// into is an app you have to delete and reinstall.
struct SettingsView: View {
    @ObservedObject var store: MorningStore
    let canDismiss: Bool
    @Binding var isPresented: Bool

    @State private var token = ""
    @State private var isReplacing = false
    @State private var isSaving = false
    @Environment(\.theme) private var theme

    private let tokenURL = URL(string: "https://q.utoronto.ca/profile/settings")!

    private var isConnected: Bool { store.hasQuercusToken }
    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isConnected && !isReplacing {
                    connected
                } else {
                    entry
                }

                Text("The token is stored in the iPhone's Keychain, kept off iCloud and out of backups, and is never included in an export.")
                    .font(theme.type.meta)
                    .foregroundStyle(theme.palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if !store.missingFonts.isEmpty {
                    Text("Typography unavailable: \(store.missingFonts.joined(separator: ", "))")
                        .font(theme.type.meta)
                        .foregroundStyle(theme.doubtColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(19)
        }
        .background(theme.palette.newsprint.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aubade")
                    .font(theme.type.masthead)
                    .foregroundStyle(theme.palette.ink)
                Spacer(minLength: 8)
                if canDismiss {
                    Button { isPresented = false } label: {
                        Text("Done".uppercased())
                            .font(theme.type.folioEmphasis)
                            .tracking(1.2)
                            .foregroundStyle(theme.palette.spot)
                    }
                    .buttonStyle(.plain)
                }
            }
            Rectangle().frame(height: 2.5).foregroundStyle(theme.palette.ink)
        }
    }

    private var connected: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quercus is connected")
                .font(theme.type.lead)
                .foregroundStyle(theme.palette.ink)

            Text("Aubade reads your coursework and nothing else. If the token stops working, Quercus says so at the top of the edition — replace it here.")
                .font(theme.type.standfirst)
                .foregroundStyle(theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Button { isReplacing = true } label: {
                Text("Replace token".uppercased())
                    .font(theme.type.folioEmphasis)
                    .tracking(1.2)
                    .foregroundStyle(theme.palette.spot)
            }
            .buttonStyle(.plain)

            Button {
                Task { await store.disconnectQuercus() }
            } label: {
                Text("Disconnect Quercus".uppercased())
                    .font(theme.type.folioEmphasis)
                    .tracking(1.2)
                    .foregroundStyle(theme.doubtColor)
            }
            .buttonStyle(.plain)

            Text("Disconnecting removes the token from this phone. Editions already saved are kept and expire on their own after thirty days.")
                .font(theme.type.meta)
                .foregroundStyle(theme.palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var entry: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isReplacing ? "Replace the token" : "Connect Quercus")
                .font(theme.type.lead)
                .foregroundStyle(theme.palette.ink)

            Text("Aubade reads your coursework with a personal access token that you generate and can revoke at any moment. It only ever reads: it cannot submit work, change anything, or see your grades.")
                .font(theme.type.standfirst)
                .foregroundStyle(theme.palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: tokenURL) {
                Text("Open Quercus settings".uppercased())
                    .font(theme.type.folioEmphasis)
                    .tracking(1.2)
                    .foregroundStyle(theme.palette.spot)
            }

            Text("Account → Settings → New Access Token")
                .font(theme.type.meta)
                .foregroundStyle(theme.palette.inkMuted)

            SecureField("Paste the token", text: $token)
                .textFieldStyle(.plain)
                .font(theme.type.brief)
                .foregroundStyle(theme.palette.ink)
                .padding(9)
                .overlay { Rectangle().stroke(theme.palette.ink, lineWidth: 1) }

            Button {
                Task {
                    isSaving = true
                    await store.saveQuercusToken(trimmedToken)
                    isSaving = false
                    token = ""
                    isReplacing = false
                    if canDismiss { isPresented = false }
                }
            } label: {
                Text((isSaving ? "Connecting…" : "Connect").uppercased())
                    .font(theme.type.folioEmphasis)
                    .tracking(1.4)
                    .foregroundStyle(theme.palette.newsprint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(trimmedToken.isEmpty ? theme.palette.stamp : theme.palette.ink)
            }
            .buttonStyle(.plain)
            .disabled(trimmedToken.isEmpty || isSaving)

            if isReplacing {
                Button { isReplacing = false; token = "" } label: {
                    Text("Cancel".uppercased())
                        .font(theme.type.folio)
                        .tracking(1.2)
                        .foregroundStyle(theme.palette.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
