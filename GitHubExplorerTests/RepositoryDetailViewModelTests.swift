import Testing
import Foundation
@testable import GitHubExplorer

@Suite("Repository Detail ViewModel Tests")
struct RepositoryDetailViewModelTests {
    
    // MARK: - Test Data
    
    private var sampleOwner: Owner {
        Owner(
            id: 123,
            login: "testowner",
            avatarUrl: "https://avatars.githubusercontent.com/u/123?v=4"
        )
    }
    
    private var sampleRepository: Repository {
        Repository(
            id: 456,
            name: "TestRepository",
            owner: sampleOwner,
            forksCount: 100,
            stargazersCount: 500,
            description: "A test repository for unit testing purposes"
        )
    }
    
    private var popularRepository: Repository {
        Repository(
            id: 789,
            name: "PopularRepo",
            owner: sampleOwner,
            forksCount: 5000,
            stargazersCount: 15000,
            description: "A very popular repository"
        )
    }
    
    private var repositoryWithoutOwner: Repository {
        Repository(
            id: 999,
            name: "OrphanRepo",
            owner: nil,
            forksCount: 0,
            stargazersCount: 0,
            description: nil
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("ViewModel initializes with repository data")
    func testViewModelInitialization() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.repository.id == sampleRepository.id)
        #expect(viewModel.repository.name == sampleRepository.name)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isDescriptionExpanded == false)
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("Owner name returns correct value")
    func testOwnerName() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.ownerName == "testowner")
    }
    
    @Test("Owner name returns default when owner is nil")
    func testOwnerNameWithNilOwner() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: repositoryWithoutOwner,
            apiService: mockAPIService
        )
        
        #expect(viewModel.ownerName == "Unknown Owner")
    }
    
    @Test("Repository name returns correct value")
    func testRepositoryName() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.repositoryName == "TestRepository")
    }
    
    @Test("Repository name returns default when name is nil")
    func testRepositoryNameWithNilName() async {
        let mockAPIService = MockAPIService()
        var repoWithoutName = sampleRepository
        repoWithoutName.name = nil
        let viewModel = RepositoryDetailViewModel(
            repository: repoWithoutName,
            apiService: mockAPIService
        )
        
        #expect(viewModel.repositoryName == "Unnamed Repository")
    }
    
    @Test("Description returns correct value")
    func testDescription() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.description == "A test repository for unit testing purposes")
    }
    
    @Test("Description returns nil when repository description is nil")
    func testDescriptionWithNilDescription() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: repositoryWithoutOwner,
            apiService: mockAPIService
        )
        
        #expect(viewModel.description == nil)
    }
    
    @Test("Star count returns formatted string")
    func testStarCount() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.starCount == "500")
    }
    
    @Test("Star count returns zero when stargazers count is nil")
    func testStarCountWithNilValue() async {
        let mockAPIService = MockAPIService()
        var repoWithoutStars = sampleRepository
        repoWithoutStars.stargazersCount = nil
        let viewModel = RepositoryDetailViewModel(
            repository: repoWithoutStars,
            apiService: mockAPIService
        )
        
        #expect(viewModel.starCount == "0")
    }
    
    @Test("Fork count returns formatted string")
    func testForkCount() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.forkCount == "100")
    }
    
    @Test("Fork count returns zero when forks count is nil")
    func testForkCountWithNilValue() async {
        let mockAPIService = MockAPIService()
        var repoWithoutForks = sampleRepository
        repoWithoutForks.forksCount = nil
        let viewModel = RepositoryDetailViewModel(
            repository: repoWithoutForks,
            apiService: mockAPIService
        )
        
        #expect(viewModel.forkCount == "0")
    }
    
    @Test("Is popular returns true for popular repository")
    func testIsPopularForPopularRepo() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: popularRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.isPopular == true)
    }
    
    @Test("Is popular returns false for regular repository")
    func testIsPopularForRegularRepo() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.isPopular == false)
    }
    
    @Test("Owner avatar URL returns correct value")
    func testOwnerAvatarUrl() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.ownerAvatarUrl == "https://avatars.githubusercontent.com/u/123?v=4")
    }
    
    @Test("Owner avatar URL returns empty string when owner is nil")
    func testOwnerAvatarUrlWithNilOwner() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: repositoryWithoutOwner,
            apiService: mockAPIService
        )
        
        #expect(viewModel.ownerAvatarUrl == "")
    }
    
    @Test("Repository URL returns correct GitHub URL")
    func testRepositoryUrl() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        let expectedUrl = URL(string: "https://github.com/testowner/TestRepository")!
        #expect(viewModel.repositoryUrl == expectedUrl)
    }
    
    @Test("Repository URL returns fallback when construction fails")
    func testRepositoryUrlFallback() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: repositoryWithoutOwner,
            apiService: mockAPIService
        )
        
        let fallbackUrl = URL(string: "https://github.com")!
        #expect(viewModel.repositoryUrl == fallbackUrl)
    }
    
    // MARK: - Async Operation Tests
    
    @Test("Refresh repository details updates repository on success")
    func testRefreshRepositoryDetailsSuccess() async {
        let mockAPIService = MockAPIService()
        let updatedRepository = Repository(
            id: 456,
            name: "UpdatedTestRepository",
            owner: sampleOwner,
            forksCount: 200,
            stargazersCount: 1000,
            description: "Updated description"
        )
        mockAPIService.mockRepositoryDetails = updatedRepository
        
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        await viewModel.refreshRepositoryDetails()
        
        #expect(viewModel.repository.name == "UpdatedTestRepository")
        #expect(viewModel.repository.forksCount == 200)
        #expect(viewModel.repository.stargazersCount == 1000)
        #expect(viewModel.repository.description == "Updated description")
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("Refresh repository details sets error message on failure")
    func testRefreshRepositoryDetailsFailure() async {
        let mockAPIService = MockAPIService()
        mockAPIService.shouldThrowError = true
        
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        await viewModel.refreshRepositoryDetails()
        
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to refresh repository details") == true)
        // Repository should remain unchanged on error
        #expect(viewModel.repository.id == sampleRepository.id)
    }
    
    @Test("Refresh repository details manages loading state correctly")
    func testRefreshRepositoryDetailsLoadingState() async {
        let mockAPIService = MockAPIService()
        mockAPIService.mockRepositoryDetails = sampleRepository
        mockAPIService.delayResponse = true
        
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        // Start the refresh in a task
        let refreshTask = Task {
            await viewModel.refreshRepositoryDetails()
        }
        
        // Give it a moment to start
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Loading should be true during operation
        #expect(viewModel.isLoading == true)
        #expect(viewModel.errorMessage == nil)
        
        // Wait for completion
        await refreshTask.value
        
        // Loading should be false after completion
        #expect(viewModel.isLoading == false)
    }
    
    // MARK: - State Management Tests
    
    @Test("Description expanded state can be toggled")
    func testDescriptionExpandedState() async {
        let mockAPIService = MockAPIService()
        let viewModel = RepositoryDetailViewModel(
            repository: sampleRepository,
            apiService: mockAPIService
        )
        
        #expect(viewModel.isDescriptionExpanded == false)
        
        viewModel.isDescriptionExpanded = true
        #expect(viewModel.isDescriptionExpanded == true)
        
        viewModel.isDescriptionExpanded = false
        #expect(viewModel.isDescriptionExpanded == false)
    }
}

// MARK: - Mock API Service

final class MockAPIService: APIServiceProtocol {
    var shouldThrowError = false
    var delayResponse = false
    var mockRepositoryDetails: Repository?
    
    func searchRepositories(query: String, page: Int) async throws -> [Repository] {
        if shouldThrowError {
            throw APIError.networkError
        }
        return []
    }
    
    func fetchRepositoryDetails(id: Int) async throws -> Repository {
        if shouldThrowError {
            throw APIError.networkError
        }
        
        if delayResponse {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        guard let mockRepository = mockRepositoryDetails else {
            throw APIError.noData
        }
        
        return mockRepository
    }
} 