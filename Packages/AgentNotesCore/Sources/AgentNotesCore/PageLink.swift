import Foundation

/// Where a link on a page goes: another page of the same notebook, or a web page.
public enum PageLink: Equatable, Sendable {
    case page(UUID)
    case web(URL)

    /// Stored form: "page:<uuid>" or the web address.
    public var rawValue: String {
        switch self {
        case .page(let id): return "page:" + id.uuidString
        case .web(let url): return url.absoluteString
        }
    }

    public init?(rawValue: String) {
        if rawValue.hasPrefix("page:") {
            guard let id = UUID(uuidString: String(rawValue.dropFirst(5))) else { return nil }
            self = .page(id)
        } else if let url = Self.webURL(from: rawValue) {
            self = .web(url)
        } else {
            return nil
        }
    }

    /// A web address typed by a person: adds https:// when missing; only http and https are allowed.
    public static func webURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host, host.contains(".") else { return nil }
        return url
    }
}
