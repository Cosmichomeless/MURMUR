import SwiftUI

/// Transcription preferences and the links an App Store app is expected to have.
struct SettingsView: View {
    @Environment(TranscriptionService.self) private var transcription
    @Environment(SyncSettings.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var settings = transcription.settings
        @Bindable var syncSettings = sync
        NavigationStack {
            Form {
                Section {
                    Toggle("Transcribe new recordings", isOn: $settings.autoTranscribe)
                        .accessibilityIdentifier("settings.auto")

                    Picker("Language", selection: $settings.languageIdentifier) {
                        Text("Automatic").tag(String?.none)
                        ForEach(languageOptions, id: \.identifier) { option in
                            Text(option.name).tag(Optional(option.identifier))
                        }
                    }
                    .accessibilityIdentifier("settings.language")

                    if transcription.authorization == .denied || transcription.authorization == .restricted {
                        Button("Allow speech recognition in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } header: {
                    Text("Transcription")
                } footer: {
                    Text("Automatic follows your device's languages. Transcription runs on this device and your audio is never sent anywhere.")
                }

                Section {
                    Toggle("Sync with iCloud", isOn: $syncSettings.isEnabled)
                        .accessibilityIdentifier("settings.icloud")

                    if let message = syncMessage {
                        Label(message.text, systemImage: message.symbol)
                            .font(.footnote)
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Keeps your notes, transcripts and audio on all your devices through your own private iCloud. Nothing goes to MURMUR's servers, and it is off unless you turn it on.")
                }

                Section("About") {
                    Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                        .accessibilityIdentifier("settings.privacy")
                    Link("Support", destination: AppLinks.support)
                        .accessibilityIdentifier("settings.support")
                    LabeledContent("Version", value: Self.versionText)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await transcription.loadAvailableLocales() }
        }
    }

    /// What to tell the user about sync, most pressing first.
    private var syncMessage: (text: LocalizedStringKey, symbol: String)? {
        if sync.needsRestart {
            return ("Restart MURMUR to apply this change.", "arrow.clockwise")
        }
        guard sync.isEnabled else { return nil }
        switch sync.lastIssue {
        case .noAccount:
            return ("Sign in to iCloud in the Settings app to sync.", "person.crop.circle.badge.exclamationmark")
        case .unavailable:
            return ("iCloud isn't available right now. Your notes stay on this device.", "exclamationmark.icloud")
        case .quotaExceeded:
            return ("Your iCloud storage is full, so new audio can't be uploaded.", "exclamationmark.icloud")
        case nil:
            if FileManager.default.ubiquityIdentityToken == nil {
                return ("Sign in to iCloud in the Settings app to sync.", "person.crop.circle.badge.exclamationmark")
            }
            return ("Syncing with iCloud.", "checkmark.icloud")
        }
    }

    private struct LanguageOption {
        let identifier: String
        let name: String
    }

    /// The languages this device can transcribe, plus the chosen one even if it is not listed any more.
    private var languageOptions: [LanguageOption] {
        var identifiers = transcription.availableLocales.map { $0.identifier(.bcp47) }
        if let chosen = transcription.settings.languageIdentifier, !identifiers.contains(chosen) {
            identifiers.append(chosen)
        }
        return identifiers
            .map { LanguageOption(identifier: $0, name: Locale.current.localizedString(forIdentifier: $0) ?? $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
