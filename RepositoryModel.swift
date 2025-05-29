import Foundation

// MARK: - Repository Model
struct Repository: Codable, Identifiable {
    let id: Int
    let nodeId: String
    let name: String
    let fullName: String
    let owner: Owner
    let isPrivate: Bool
    let htmlUrl: String
    let description: String?
    let fork: Bool
    let url: String
    let createdAt: String
    let updatedAt: String
    let pushedAt: String?
    let gitUrl: String
    let sshUrl: String
    let cloneUrl: String
    let svnUrl: String
    let homepage: String?
    let size: Int
    let stargazersCount: Int
    let watchersCount: Int
    let language: String?
    let hasIssues: Bool
    let hasProjects: Bool
    let hasWiki: Bool
    let hasPages: Bool
    let forksCount: Int
    let archived: Bool
    let disabled: Bool
    let openIssuesCount: Int
    let license: License?
    let allowForking: Bool
    let isTemplate: Bool
    let topics: [String]
    let visibility: String
    let forks: Int
    let openIssues: Int
    let watchers: Int
    let defaultBranch: String
    let score: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case nodeId = "node_id"
        case name
        case fullName = "full_name"
        case owner
        case isPrivate = "private"
        case htmlUrl = "html_url"
        case description
        case fork
        case url
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
        case gitUrl = "git_url"
        case sshUrl = "ssh_url"
        case cloneUrl = "clone_url"
        case svnUrl = "svn_url"
        case homepage
        case size
        case stargazersCount = "stargazers_count"
        case watchersCount = "watchers_count"
        case language
        case hasIssues = "has_issues"
        case hasProjects = "has_projects"
        case hasWiki = "has_wiki"
        case hasPages = "has_pages"
        case forksCount = "forks_count"
        case archived
        case disabled
        case openIssuesCount = "open_issues_count"
        case license
        case allowForking = "allow_forking"
        case isTemplate = "is_template"
        case topics
        case visibility
        case forks
        case openIssues = "open_issues"
        case watchers
        case defaultBranch = "default_branch"
        case score
    }
}

// MARK: - Owner Model
struct Owner: Codable {
    let login: String
    let id: Int
    let nodeId: String
    let avatarUrl: String
    let gravatarId: String
    let url: String
    let htmlUrl: String
    let followersUrl: String
    let followingUrl: String
    let gistsUrl: String
    let starredUrl: String
    let subscriptionsUrl: String
    let organizationsUrl: String
    let reposUrl: String
    let eventsUrl: String
    let receivedEventsUrl: String
    let type: String
    let siteAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case login
        case id
        case nodeId = "node_id"
        case avatarUrl = "avatar_url"
        case gravatarId = "gravatar_id"
        case url
        case htmlUrl = "html_url"
        case followersUrl = "followers_url"
        case followingUrl = "following_url"
        case gistsUrl = "gists_url"
        case starredUrl = "starred_url"
        case subscriptionsUrl = "subscriptions_url"
        case organizationsUrl = "organizations_url"
        case reposUrl = "repos_url"
        case eventsUrl = "events_url"
        case receivedEventsUrl = "received_events_url"
        case type
        case siteAdmin = "site_admin"
    }
}

// MARK: - License Model
struct License: Codable {
    let key: String
    let name: String
    let spdxId: String?
    let url: String?
    let nodeId: String

    enum CodingKeys: String, CodingKey {
        case key
        case name
        case spdxId = "spdx_id"
        case url
        case nodeId = "node_id"
    }
}

// MARK: - Search Response Model
struct SearchResponse: Codable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [Repository]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

// MARK: - Repository Extensions for UI
extension Repository {
    var displayName: String {
        return name
    }

    var displayDescription: String {
        return description ?? "No description available"
    }

    var displayLanguage: String {
        return language ?? "Unknown"
    }

    var formattedStarCount: String {
        if stargazersCount >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            let thousands = Double(stargazersCount) / 1000.0
            return "\(formatter.string(from: NSNumber(value: thousands)) ?? "0")k"
        } else {
            return "\(stargazersCount)"
        }
    }

    var formattedForkCount: String {
        if forksCount >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            let thousands = Double(forksCount) / 1000.0
            return "\(formatter.string(from: NSNumber(value: thousands)) ?? "0")k"
        } else {
            return "\(forksCount)"
        }
    }

    var lastUpdatedDate: Date? {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: updatedAt)
    }

    var formattedLastUpdated: String {
        guard let lastUpdated = lastUpdatedDate else { return "Unknown" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}