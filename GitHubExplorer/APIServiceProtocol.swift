import Foundation

enum APIError: Error {
    case badURL
    case decodingError
}

protocol APIServiceProtocol {
    func fetchRepositories(category: RepoCategory) async throws -> [Repository]
    func searchRepositories(query: String) async throws -> [Repository]
    func fetchRepositoryDetails(id: Int) async throws -> Repository
}

struct APIServiceImpl: APIServiceProtocol {

    func fetchRepositories(category: RepoCategory) async throws -> [Repository] {
        let query = "\(category.rawValue) language:swift"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.github.com/search/repositories?q=\(encodedQuery)&sort=stars&order=desc") else {
            throw APIError.badURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        do {
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            return searchResponse.items
        } catch {
            throw APIError.decodingError
        }
    }

    func searchRepositories(query: String) async throws -> [Repository] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.github.com/search/repositories?q=\(encodedQuery)") else {
            throw APIError.badURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        do {
            let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
            return searchResponse.items
        } catch {
            throw APIError.decodingError
        }
    }

    func fetchRepositoryDetails(id: Int) async throws -> Repository {
        guard let url = URL(string: "https://api.github.com/repositories/\(id)") else {
            throw APIError.badURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        do {
            return try JSONDecoder().decode(Repository.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}

struct Repository: Decodable, Identifiable {
    let id: Int
    let name: String?
    let owner: Owner?
    let forksCount: Int?
    let stargazersCount: Int?
    let description: String?

    // Computed properties for display
    var starRating: String {
        // For a visual representation, limiting the count to max 5 stars
        let count = (stargazersCount ?? 0) / 2000
        return String(repeating: "⭐", count: min(max(count, 0), 5))
    }
    var isPopular: Bool { (stargazersCount ?? 0) >= 1000 }
    var formattedForks: String { "\(forksCount ?? 0) forks" }

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description
        case forksCount = "forks_count"
        case stargazersCount = "stargazers_count"
    }
}

struct Owner: Decodable, Identifiable {
    let id: Int
    let login: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, login
        case avatarUrl = "avatar_url"
    }
}

// Add this struct so that the search response can be decoded properly.
struct SearchResponse: Decodable {
    let items: [Repository]
}
