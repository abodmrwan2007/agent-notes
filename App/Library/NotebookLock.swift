import LocalAuthentication
import SwiftUI

/// Face ID / Touch ID / device passcode gate for locked notebooks.
///
/// Honest scope: this stops a locked notebook from being opened, previewed, or searched inside
/// the app. It is not separate encryption: the files are protected on disk by iPadOS Data
/// Protection like all app data, and anyone who can unlock the iPad itself can authenticate.
enum NotebookLock {
    /// nil on success. An empty string when the person cancelled (show nothing); otherwise a
    /// message to show.
    static func authenticate(reason: String) async -> String? {
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            return String(localized: "Set a passcode on this iPad to lock notebooks.")
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success ? nil : String(localized: "The notebook could not be unlocked.")
        } catch let error as LAError where [.userCancel, .appCancel, .systemCancel].contains(error.code) {
            return ""
        } catch {
            return error.localizedDescription
        }
    }
}

/// A cover colour shown on the library card instead of the first page.
enum NotebookCover: String, CaseIterable, Identifiable {
    case navy
    case ocean
    case coral
    case forest
    case sand
    case plum

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .navy: return "Navy"
        case .ocean: return "Ocean"
        case .coral: return "Coral"
        case .forest: return "Forest"
        case .sand: return "Sand"
        case .plum: return "Plum"
        }
    }

    var colors: [Color] {
        switch self {
        case .navy: return [Color(red: 0.10, green: 0.17, blue: 0.36), Color(red: 0.05, green: 0.09, blue: 0.21)]
        case .ocean: return [Color(red: 0.12, green: 0.68, blue: 0.82), Color(red: 0.05, green: 0.42, blue: 0.62)]
        case .coral: return [Color(red: 0.98, green: 0.52, blue: 0.45), Color(red: 0.86, green: 0.30, blue: 0.36)]
        case .forest: return [Color(red: 0.25, green: 0.62, blue: 0.42), Color(red: 0.11, green: 0.38, blue: 0.27)]
        case .sand: return [Color(red: 0.96, green: 0.86, blue: 0.64), Color(red: 0.86, green: 0.70, blue: 0.45)]
        case .plum: return [Color(red: 0.58, green: 0.38, blue: 0.78), Color(red: 0.36, green: 0.20, blue: 0.55)]
        }
    }

    var textColor: Color { self == .sand ? Color(red: 0.25, green: 0.18, blue: 0.08) : .white }
}

/// Front of a notebook with a chosen cover: gradient, spine and the title.
struct NotebookCoverView: View {
    let cover: NotebookCover
    let title: String

    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: cover.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            // Spine.
            Rectangle()
                .fill(.black.opacity(0.18))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(cover.textColor.opacity(0.7))
                    .frame(width: 34, height: 3)
                Text(verbatim: title)
                    .font(.headline)
                    .foregroundStyle(cover.textColor)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, 28)
            .padding([.trailing, .bottom], 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}

/// What a locked notebook shows in the library: never its pages.
struct LockedCoverView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accent)
                Text("Locked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
