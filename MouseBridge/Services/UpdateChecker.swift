import Foundation

struct GitHubReleaseVersion: Equatable, Sendable {
    static func buildNumber(in tagName: String) -> Int? {
        guard let open = tagName.lastIndex(of: "("),
              let close = tagName.lastIndex(of: ")"),
              open < close else {
            return nil
        }
        let value = tagName[tagName.index(after: open)..<close]
        return Int(value)
    }
}

struct GitHubLatestReleasePayload: Decodable, Equatable, Sendable {
    var tagName: String
    var name: String
    var body: String
    var htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try container.decode(String.self, forKey: .tagName)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? tagName
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        htmlURL = try container.decode(URL.self, forKey: .htmlURL)
    }

    init(tagName: String, name: String, body: String, htmlURL: URL) {
        self.tagName = tagName
        self.name = name
        self.body = body
        self.htmlURL = htmlURL
    }
}

struct AvailableUpdate: Equatable, Sendable {
    var buildNumber: Int
    var name: String
    var body: String
    var htmlURL: URL
}

enum UpdateCheckStatus: Equatable, Sendable {
    case notChecked
    case latest
    case updateAvailable

    var titleKey: String {
        switch self {
        case .notChecked:
            "updates.status.notChecked"
        case .latest:
            "updates.status.latest"
        case .updateAvailable:
            "updates.status.updateAvailable"
        }
    }
}

enum UpdateCheckResult: Equatable, Sendable {
    case updateAvailable(AvailableUpdate)
    case upToDate
    case notModified
    case unavailable
    case skipped
}

enum UpdateCheckTrigger: Equatable, Sendable {
    case automatic
    case manual
}

struct UpdateCheckEvaluator: Sendable {
    static func evaluate(payload: GitHubLatestReleasePayload, currentBuildNumber: Int) -> UpdateCheckResult {
        guard let latestBuildNumber = GitHubReleaseVersion.buildNumber(in: payload.tagName) else {
            return .upToDate
        }
        guard latestBuildNumber > currentBuildNumber else {
            return .upToDate
        }
        return .updateAvailable(
            AvailableUpdate(
                buildNumber: latestBuildNumber,
                name: payload.name,
                body: payload.body,
                htmlURL: payload.htmlURL
            )
        )
    }
}

final class UpdateCheckPolicy {
    static let automaticCheckInterval: TimeInterval = 86_400
    static let manualCheckInterval: TimeInterval = 60
    static let suppressPromptInterval: TimeInterval = 7 * 86_400

    private enum Keys {
        static let lastAutomaticCheckAt = "updates.lastAutomaticCheckAt"
        static let lastManualCheckAt = "updates.lastManualCheckAt"
        static let suppressAutomaticPromptsUntil = "updates.suppressAutomaticPromptsUntil"
        static let latestReleaseETag = "updates.latestReleaseETag"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func shouldBeginCheck(trigger: UpdateCheckTrigger, now: Date = Date()) -> Bool {
        switch trigger {
        case .automatic:
            if let suppressUntil = defaults.object(forKey: Keys.suppressAutomaticPromptsUntil) as? Date,
               suppressUntil > now {
                return false
            }
            guard let lastCheck = defaults.object(forKey: Keys.lastAutomaticCheckAt) as? Date else {
                return true
            }
            return now.timeIntervalSince(lastCheck) >= Self.automaticCheckInterval
        case .manual:
            guard let lastCheck = defaults.object(forKey: Keys.lastManualCheckAt) as? Date else {
                return true
            }
            return now.timeIntervalSince(lastCheck) >= Self.manualCheckInterval
        }
    }

    func recordCheckStarted(trigger: UpdateCheckTrigger, now: Date = Date()) {
        switch trigger {
        case .automatic:
            defaults.set(now, forKey: Keys.lastAutomaticCheckAt)
        case .manual:
            defaults.set(now, forKey: Keys.lastManualCheckAt)
        }
    }

    func shouldPresentUpdatePrompt(trigger: UpdateCheckTrigger, now: Date = Date()) -> Bool {
        switch trigger {
        case .manual:
            return true
        case .automatic:
            guard let suppressUntil = defaults.object(forKey: Keys.suppressAutomaticPromptsUntil) as? Date else {
                return true
            }
            return suppressUntil <= now
        }
    }

    func suppressAutomaticPrompts(until date: Date) {
        defaults.set(date, forKey: Keys.suppressAutomaticPromptsUntil)
    }

    var cachedETag: String? {
        defaults.string(forKey: Keys.latestReleaseETag)
    }

    func storeETag(_ eTag: String?) {
        guard let eTag, !eTag.isEmpty else { return }
        defaults.set(eTag, forKey: Keys.latestReleaseETag)
    }
}

final class UpdateChecker {
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/PHalfStudio/ScrollBridge/releases/latest")!

    private let policy: UpdateCheckPolicy
    private let decoder: JSONDecoder

    init(policy: UpdateCheckPolicy = UpdateCheckPolicy(), decoder: JSONDecoder = JSONDecoder()) {
        self.policy = policy
        self.decoder = decoder
    }

    func check(currentBuildNumber: Int, trigger: UpdateCheckTrigger, now: Date = Date()) async -> UpdateCheckResult {
        guard policy.shouldBeginCheck(trigger: trigger, now: now) else {
            return .skipped
        }
        policy.recordCheckStarted(trigger: trigger, now: now)
        var request = URLRequest(url: Self.latestReleaseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("ScrollBridge", forHTTPHeaderField: "User-Agent")
        if let eTag = policy.cachedETag {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .unavailable
            }
            if httpResponse.statusCode == 304 {
                return .notModified
            }
            guard httpResponse.statusCode == 200 else {
                return .unavailable
            }
            policy.storeETag(httpResponse.value(forHTTPHeaderField: "ETag"))
            let payload = try decoder.decode(GitHubLatestReleasePayload.self, from: data)
            return UpdateCheckEvaluator.evaluate(payload: payload, currentBuildNumber: currentBuildNumber)
        } catch {
            return .unavailable
        }
    }

    func shouldPresentUpdatePrompt(trigger: UpdateCheckTrigger, now: Date = Date()) -> Bool {
        policy.shouldPresentUpdatePrompt(trigger: trigger, now: now)
    }

    func suppressAutomaticPromptsForSevenDays(now: Date = Date()) {
        policy.suppressAutomaticPrompts(until: now.addingTimeInterval(UpdateCheckPolicy.suppressPromptInterval))
    }
}
