import SwiftUI

@main
struct AubadeTrialApp: App {
    var body: some Scene {
        WindowGroup {
            TrialView()
        }
    }
}

private struct TrialView: View {
    @AppStorage("trial.savedMarker") private var savedMarker = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Hello, morning.", systemImage: "sunrise")
                        .font(.title2.weight(.semibold))
                    Text("Aubade is running as a native iPhone app.")
                    Text("Installation trial · No accounts connected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Check local storage") {
                    Text("Save a marker, close the app, and open it again. Then refresh the app through Sideloadly without uninstalling it. The same marker should remain.")

                    if savedMarker.isEmpty {
                        Button("Save a test marker") {
                            savedMarker = UUID().uuidString
                        }
                        .accessibilityHint("Stores a test identifier on this phone")
                    } else {
                        Label("Marker saved", systemImage: "checkmark.circle.fill")
                        Text(savedMarker)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                        ShareLink(item: "Aubade installation trial\nSaved marker: \(savedMarker)") {
                            Label("Export marker", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("Trial checklist") {
                    Label("Launch without a network connection", systemImage: "airplane")
                    Label("Check text at your preferred text size", systemImage: "textformat.size")
                    Label("Refresh signing and reopen this app", systemImage: "arrow.clockwise")
                }

                Section {
                    Text("This trial does not fetch email, coursework, or news. Its purpose is to verify installation, offline launch, export, and data retention after refresh.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Aubade Trial")
        }
    }
}
