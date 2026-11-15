import AgentNotesCore
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.allowsFingerDrawing) private var allowsFingerDrawing = false
    @AppStorage(SettingsKey.defaultTemplate) private var defaultTemplateRaw = PageTemplate.ruled.rawValue
    @AppStorage(SettingsKey.snapShapesOnHold) private var snapShapesOnHold = true
    @AppStorage(SettingsKey.smoothingStrength) private var smoothingStrength = 0.0
    @AppStorage(SettingsKey.scribbleToErase) private var scribbleToErase = true
    @AppStorage(AccentChoice.storageKey) private var interfaceColor = AccentChoice.cyan.rawValue

    var body: some View {
        Form {
            Section {
                Toggle("Draw with finger", isOn: $allowsFingerDrawing)
            } header: {
                Text("Writing")
            } footer: {
                Text("When off, only Apple Pencil draws and one finger scrolls. When on, one finger draws and two fingers scroll.")
            }

            Section {
                Toggle("Straighten shapes when holding the pen at the end", isOn: $snapShapesOnHold)
                Toggle("Scribble over ink to erase it", isOn: $scribbleToErase)
                VStack(alignment: .leading) {
                    Text("Stroke smoothing")
                    Slider(value: $smoothingStrength, in: 0...1) {
                        Text("Stroke smoothing")
                    } minimumValueLabel: {
                        Text("Off")
                    } maximumValueLabel: {
                        Text("Strong")
                    }
                }
            } header: {
                Text("Shapes and smoothing")
            } footer: {
                Text("Draw a line, circle, ellipse or rectangle and keep the pen still for half a second before lifting it. Both features apply when the stroke is finished, not while you write. Undo removes the corrected stroke.")
                Text("To erase, scribble back and forth at least five times across the strokes. Undo brings them back.")
            }

            Section("Appearance") {
                Picker("Interface color", selection: $interfaceColor) {
                    ForEach(AccentChoice.allCases) { choice in
                        Label {
                            Text(choice.title)
                        } icon: {
                            Image(systemName: "circle.fill").foregroundStyle(choice.color)
                        }
                        .tag(choice.rawValue)
                    }
                }
                .accessibilityIdentifier("settings.interfaceColor")
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
