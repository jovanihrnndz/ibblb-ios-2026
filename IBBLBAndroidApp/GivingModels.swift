import Foundation

public struct GivingPageModel: Codable, Hashable {
    let title: String
    let content: String?
    let onlineGivingUrl: String?

    var bodyText: String {
        guard let content, !content.isEmpty else {
            return "Give online securely through our church giving platform."
        }
        return content
    }

    var givingURL: URL? {
        guard let onlineGivingUrl,
              let url = URL(string: onlineGivingUrl),
              let scheme = url.scheme,
              (scheme == "https" || scheme == "http") else {
            return nil
        }
        return url
    }
}

public enum GivingFixtures {
    static let sample = GivingPageModel(
        title: "Give",
        content: "Support the ministry of Iglesia Bautista Biblica de Long Beach through one-time or recurring gifts.",
        onlineGivingUrl: "https://give.ibblb.org"
    )
}
