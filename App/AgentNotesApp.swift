import SwiftUI

@main
struct AgentNotesApp: App {
    @State private var boot: Result<AppModel, Error>

    init() {
        do {
            _boot = State(initialValue: .success(try AppModel()))
        } catch {
            _boot = State(initialValue: .failure(error))
        }
    }

    var body: some Scene {
        WindowGroup {
            switch boot {
            case .success(let app):
                RootView()
                    .environment(app)
                    .tint(Theme.accent)
            case .failure(let error):
                // Local storage could not be opened. Say so instead of showing an empty library.
                ContentUnavailableView {
                    Label("Storage unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("The notes library could not be opened on this device.")
                    Text(verbatim: error.localizedDescription)
                }
            }
        }
    }
}
