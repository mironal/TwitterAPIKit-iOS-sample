import Foundation
import TwitterAPIKit

struct Env: Codable {
    // MARK: - OAUTH 1.0a
    var consumerKey: String?
    var consumerSecret: String?

    var oauthToken: String?
    var oauthTokenSecret: String?

    // MARK: - OAuth 2.0 Authorization Code Flow with PKCE
    var clientID: String?
    var clientSecret: String?

    var token: TwitterAuthenticationMethod.OAuth20?
}

extension Env {
    func store(_ defaults: UserDefaults = .standard) {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(self)
        defaults.set(data, forKey: "Twitter.Env")
    }

    static func restore(_ defaults: UserDefaults = .standard) -> Self? {
        guard let data = defaults.data(forKey: "Twitter.Env") else { return nil }
        let decoder = JSONDecoder()
        let env = try? decoder.decode(Self.self, from: data)
        return env
    }

    static func reset(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: "Twitter.Env")
    }
}
