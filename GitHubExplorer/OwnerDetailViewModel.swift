import Foundation

@MainActor
class OwnerDetailViewModel: ObservableObject {
    @Published private(set) var repositories: [Repository] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let owner: Owner
    private let apiService: APIServiceProtocol

    var ownerName: String {
        owner.login ?? "Unknown User"
    }

    var totalStars: Int {
        repositories.reduce(0) { $0 + ($1.stargazersCount ?? 0) }
    }

    var repositoryCount: Int {
        repositories.count
    }

    var sortedRepositories: [Repository] {
        repositories.sorted { ($0.stargazersCount ?? 0) > ($1.stargazersCount ?? 0) }
    }

    init(owner: Owner, apiService: APIServiceProtocol = APIServiceImpl()) {
        self.owner = owner
        self.apiService = apiService
    }

    func fetchOwnerRepositories() async {
        isLoading = true
        errorMessage = nil

        do {
            let query = "user:\(owner.login ?? "")"
            repositories = try await apiService.searchRepositories(query: query)
        } catch {
            errorMessage = "Failed to load repositories: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
