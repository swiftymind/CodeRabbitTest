import Foundation
import Combine

struct RepositoryService {
    private let session = URLSession.shared
    private let baseURL = "https://api.github.com"

    enum APIError: Error, LocalizedError {
        case invalidURL
        case noData
        case decodingError
        case networkError(Error)
        case rateLimitExceeded
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noData:
                return "No data received"
            case .decodingError:
                return "Failed to decode response"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .rateLimitExceeded:
                return "Rate limit exceeded. Please try again later."
            case .unauthorized:
                return "Unauthorized access"
            }
        }
    }

    func searchRepositories(query: String, page: Int = 1, perPage: Int = 30) -> AnyPublisher<SearchResponse, APIError> {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/repositories?q=\(encodedQuery)&page=\(page)&per_page=\(perPage)&sort=stars&order=desc") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("GitHub-Explorer-iOS/1.0", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError(URLError(.badServerResponse))
                }

                switch httpResponse.statusCode {
                case 200:
                    return data
                case 403:
                    throw APIError.rateLimitExceeded
                case 401:
                    throw APIError.unauthorized
                default:
                    throw APIError.networkError(URLError(.badServerResponse))
                }
            }
            .decode(type: SearchResponse.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                } else if let apiError = error as? APIError {
                    return apiError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }

    func getRepository(owner: String, name: String) -> AnyPublisher<Repository, APIError> {
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(name)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("GitHub-Explorer-iOS/1.0", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: Repository.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }

    func getUserRepositories(username: String, page: Int = 1) -> AnyPublisher<[Repository], APIError> {
        guard let url = URL(string: "\(baseURL)/users/\(username)/repos?page=\(page)&per_page=30&sort=updated") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("GitHub-Explorer-iOS/1.0", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [Repository].self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
}