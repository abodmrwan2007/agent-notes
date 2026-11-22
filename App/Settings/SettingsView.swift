import AgentNotesCore
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.allowsFingerDrawing) private var allowsFingerDrawing = false
    @AppStorage(SettingsKey.defaultTemplate) private var defaultTemplateRaw = PageTemplate.ruled.rawValue
    @AppStorage(SettingsKey.snapShapesOnHold) private var snapShapesOnHold = true
    @AppStorage(SettingsKey.smoothingStrength) private var smoothingStrength = 0.0
    @AppStorage(SettingsKey.scribbleToErase) private var scribbleToErase = true
    @AppStorage(AccentChoice.storageKey) private var interfaceColor = AccentChoice.cyan.rawValue
    @State private var showsWhatsNew = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $allowsFingerDrawing) { Label { Text("Draw with finger") } icon: { IconBadge(symbol: "hand.point.up.left.fill", color: Vivid.blue) } }
            } header: {
                Text("Writing")
            } footer: {
                Text("When off, only Apple Pencil draws and one finger scrolls. When on, one finger draws and two fingers scroll.")
            }

            Section {
                Toggle(isOn: $snapShapesOnHold) { Label { Text("Straighten shapes when holding the pen at the end") } icon: { IconBadge(symbol: "scribble", color: Vivid.purple) } }
                Toggle(isOn: $scribbleToErase) { Label { Text("Scribble over ink to erase it") } icon: { IconBadge(symbol: "eraser.fill", color: Vivid.pink) } }
                VStack(alignment: .leading) {
                    Label { Text("Stroke smoothing") } icon: { IconBadge(symbol: "wand.and.stars", color: Vivid.teal) }
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
                Picker(selection: $interfaceColor) {
                    ForEach(AccentChoice.allCases) { choice in
                        Label {
                            Text(choice.title)
                        } icon: {
                            Image(systemName: "circle.fill").foregroundStyle(choice.color)
                        }
                        .tag(choice.rawValue)
                    }
                } label: {
                    Label { Text("Interface color") } icon: { IconBadge(symbol: "paintpalette.fill", color: Vivid.orange) }
                }
                .accessibilityIdentifier("settings.interfaceColor")
            }

            Section("New notebooks") {
                Picker(selection: $defaultTemplateRaw) {
                    ForEach(PageTemplate.allCases, id: \.self) { template in
                        Text(template.title).tag(template.rawValue)
                    }
                } label: {
                    Label { Text("Default template") } icon: { IconBadge(symbol: "doc.richtext.fill", color: Vivid.green) }
                }
            }

            Section("AI") {
                NavigationLink {
                    AISettingsView()
                } label: {
                    Label { Text("AI Assistant") } icon: { IconBadge(symbol: "sparkles", color: Vivid.purple) }
                }
                .accessibilityIdentifier("settings.ai")
            }

            Section("Help") {
                Button {
                    showsWhatsNew = true
                } label: {
                    Label { Text("What's New") } icon: { IconBadge(symbol: "gift.fill", color: Vivid.pink) }
                }
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    Label { Text("Acknowledgements") } icon: { IconBadge(symbol: "heart.text.square.fill", color: Vivid.red) }
                }
            }

            Section {
                LabeledContent("Version", value: AppConfig.versionString)
                LabeledContent("Document format", value: "v\(DocumentFormat.currentVersion)")
            } header: {
                Text("About")
            } footer: {
                Text("Notes are stored only on this device in this build. The AI assistant sends only the pages you choose. Sync and subscriptions are not implemented yet.")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showsWhatsNew) {
            WhatsNewView()
        }
    }
}

/// Credits and licenses for third-party material shipped with the app.
struct AcknowledgementsView: View {
    var body: some View {
        List {
            Section(header: Text(verbatim: "Twemoji")) {
                Text(verbatim: "Copyright 2019 Twitter, Inc and other contributors. Graphics licensed under CC BY 4.0: https://creativecommons.org/licenses/by/4.0/")
                Text("Used unmodified as medical and study stickers.")
                    .foregroundStyle(.secondary)
            }
            Section(header: Text(verbatim: "BodyParts3D")) {
                Text(verbatim: "BodyParts3D, © The Database Center for Life Science, licensed under CC Attribution-Share Alike 2.1 Japan: https://creativecommons.org/licenses/by-sa/2.1/jp/deed.en. Source: https://dbarchive.biosciencedbc.jp/en/bodyparts3d/")
                Text("The 3D heart in Atlas is made from these models: parts selected, merged, reduced and coloured. The changed model is shared under the same license.")
                    .foregroundStyle(.secondary)
            }
            Section(header: Text(verbatim: "GRDB.swift")) {
                Text(verbatim: "Copyright (C) 2015-2025 Gwendal Roué. MIT License.")
                Text("Library index database (not used in the Swift Playgrounds build).")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Acknowledgements")
    }
}

