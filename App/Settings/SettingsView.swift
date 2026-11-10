import AgentNotesCore
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.allowsFingerDrawing) private var allowsFingerDrawing = false
    @AppStorage(SettingsKey.defaultTemplate) private var defaultTemplateRaw = PageTemplate.ruled.rawValue

    var body: some View {
        Form {
            Section {
                Toggle("Draw with finger", isOn: $allowsFingerDrawing)
            } header: {
                Text("Writing")
            } footer: {
                Text("When off, only Apple Pencil draws and one finger scrolls. When on, one finger draws and two fingers scroll.")
            }

            Section("New notebooks") {
                Picker("Default template", selection: $defaultTemplateRaw) {
                    ForEach(PageTemplate.allCases, id: \.self) { template in
                        Text(template.title).tag(template.rawValue)
                    }
                }
            }

            Section {
                LabeledContent("Version", value: AppConfig.versionString)
                LabeledContent("Document format", value: "v\(DocumentFormat.currentVersion)")
            } header: {
                Text("About")
            } footer: {
                Text("Notes are stored only on this device in this build. Sync, AI features, subscriptions and the atlas are not implemented yet.")
            }
        }
        .navigationTitle("Settings")
    }
}
