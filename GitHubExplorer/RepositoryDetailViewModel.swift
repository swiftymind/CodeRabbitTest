import Foundation

@MainActor
final class RepositoryDetailViewModel: ObservableObject {
    @Published private(set) var repository: Repository
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var isDescriptionExpanded = false

    private let apiService: APIServiceProtocol

    // Computed properties
    var ownerName: String {
        repository.owner?.login ?? "Unknown Owner"
    }

    var repositoryName: String {
        repository.name ?? "Unnamed Repository"
    }

    var description: String? {
        repository.description
    }

    var starCount: String {
        "\(repository.stargazersCount ?? 0)"
    }

    var forkCount: String {
        "\(repository.forksCount ?? 0)"
    }

    var isPopular: Bool {
        repository.isPopular
    }

    var ownerAvatarUrl: String {
        repository.owner?.avatarUrl ?? ""
    }

    var repositoryUrl: URL {
        URL(string: "https://github.com/\(ownerName)/\(repositoryName)") ?? URL(string: "https://github.com")!
    }

    init(repository: Repository, apiService: APIServiceProtocol = APIServiceImpl()) {
        self.repository = repository
        self.apiService = apiService
    }

    func refreshRepositoryDetails() async {
        isLoading = true
        errorMessage = nil

        do {
            repository = try await apiService.fetchRepositoryDetails(id: repository.id)
        } catch {
            errorMessage = "Failed to refresh repository details: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

