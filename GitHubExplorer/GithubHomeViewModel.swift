import Foundation
import SwiftUI

enum DisplayState: Equatable {
    case idle, loading, success, error(String)
}

enum RepoCategory: String, CaseIterable {
    case swift = "Swift"
    case iOS = "iOS"
    case algorithm = "Algorithm"
    case iOSInterview = "iOS Interview"
}

@MainActor
final class GithubHomeViewModel: ObservableObject {
    @Published var repositories: [Repository] = []
    @Published var searchResults: [Repository] = []
    @Published var displayState: DisplayState = .idle
    @Published var errorMessage: String?

    // Moved searchText to the view model
    @Published var searchText: String = ""
    @Published var selectedCategory: RepoCategory = .swift

    let apiService: APIServiceProtocol

    init(apiService: APIServiceProtocol = APIServiceImpl()) {
        self.apiService = apiService
    }

    func fetchRepositories() async {
        displayState = .loading
        do {
            self.repositories = try await apiService.fetchRepositories(category: selectedCategory)
            displayState = .success
        } catch {
            displayState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func searchRepositories() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        // If the query is empty, clear search results.
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await apiService.searchRepositories(query: "\(query) language:swift \(selectedCategory.rawValue)")
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Sorting Functions

    func sortRepositoriesByStars(ascending: Bool) {
        repositories.sort {
            ascending ? ($0.stargazersCount ?? 0) < ($1.stargazersCount ?? 0)
                      : ($0.stargazersCount ?? 0) > ($1.stargazersCount ?? 0)
        }
        searchResults.sort {
            ascending ? ($0.stargazersCount ?? 0) < ($1.stargazersCount ?? 0)
                      : ($0.stargazersCount ?? 0) > ($1.stargazersCount ?? 0)
        }
    }

    func sortRepositoriesByForks(ascending: Bool) {
        repositories.sort {
            ascending ? ($0.forksCount ?? 0) < ($1.forksCount ?? 0)
                      : ($0.forksCount ?? 0) > ($1.forksCount ?? 0)
        }
        searchResults.sort {
            ascending ? ($0.forksCount ?? 0) < ($1.forksCount ?? 0)
                      : ($0.forksCount ?? 0) > ($1.forksCount ?? 0)
        }
    }
}


