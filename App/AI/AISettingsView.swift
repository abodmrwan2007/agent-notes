import AgentNotesCore
import SwiftUI

/// Settings ▸ AI Assistant: the owner's Claude API key, the model and a daily request limit.
struct AISettingsView: View {
    @AppStorage(SettingsKey.aiModel) private var modelRaw = AIModel.opus.rawValue
    @AppStorage(SettingsKey.aiDailyLimit) private var dailyLimit = StudyAssistantService.defaultDailyLimit
    @State private var keyField = ""
    @State private var hasKey = AIKeyStore.hasKey
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                if hasKey {
                    Label("A key is saved on this iPad.", systemImage: "checkmark.seal")
                        .accessibilityIdentifier("ai.keySaved")
                    Button("Remove key", role: .destructive) {
                        AIKeyStore.delete()
                        hasKey = false
                        message = String(localized: "The key was removed from this iPad.")
                    }
                } else {
                    SecureField("Paste your API key", text: $keyField)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("ai.keyField")
                    Button("Save key") {
                        if AIKeyStore.save(keyField) {
                            hasKey = true
                            keyField = ""
                            message = String(localized: "Saved. Open a notebook, tap Tools, then the AI tab.")
                        } else {
                            message = String(localized: "The key could not be saved.")
                        }
                    }
                    .disabled(keyField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let message {
                    Text(verbatim: message).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Claude API key")
            } footer: {
                Text("Create a key at console.anthropic.com (API Keys) and set a monthly spending limit there. The key is kept in this iPad's Keychain only. Never share it or put it in a file.")
            }

            Section {
                Picker("Model", selection: $modelRaw) {
                    ForEach(AIModel.allCases) { model in
                        Text(verbatim: model.displayName).tag(model.rawValue)
                    }
                }
                .accessibilityIdentifier("ai.model")
                Stepper(value: $dailyLimit, in: 1...200) {
                    Text("Daily limit: \(dailyLimit) requests")
                }
                LabeledContent("Used today") {
                    Text(verbatim: "\(StudyAssistantService.usage.used(on: Date()))")
                }
            } header: {
                Text("Model and limit")
            } footer: {
                Text("Opus is the most capable and the most expensive; Haiku is much cheaper. A one-page summary costs roughly a few cents with Opus, less than a cent with Haiku.")
            }

            Section {
                Text("Summaries, flashcards and quizzes, explanations and questions send a picture and the text of the chosen pages to Anthropic. Answers can be wrong: check important medical facts against your textbook.")
                    .font(.callout)
            } header: {
                Text("Privacy and accuracy")
            }
        }
        .navigationTitle("AI Assistant")
    }
}
