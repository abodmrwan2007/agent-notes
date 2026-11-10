import AgentNotesCore
import Foundation
import UniformTypeIdentifiers

/// Central, configurable product settings. Nothing here is user data.
enum AppConfig {
    /// The display name is configurable through the `APP_DISPLAY_NAME` build setting (project.yml).
    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Agent Notes"
    }

    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }

    /// Ink is written this long after the last stroke change…
    static let autosaveDelay: TimeInterval = 0.8
    /// …but never later than this after the first unsaved change, even during continuous writing.
    static let autosaveMaxLatency: TimeInterval = 3

    static let defaultPageSize = PageSize.a4
    /// Scale used to rasterize ink into exported PDFs (PDF page content itself stays vector).
    static let exportInkScale: CGFloat = 3
}

enum SettingsKey {
    static let allowsFingerDrawing = "allowsFingerDrawing"
    static let defaultTemplate = "defaultTemplate"
    static let librarySort = "librarySort"
}

extension UTType {
    /// The native editable document package. Declared in Info.plist (see project.yml).
    static let agentNote: UTType = UTType(exportedAs: "com.agentnotes.document")
}
