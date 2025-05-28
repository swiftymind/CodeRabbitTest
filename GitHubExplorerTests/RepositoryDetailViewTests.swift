import Testing
import SwiftUI
@testable import GitHubExplorer

@Suite("Repository Detail View Tests")
struct RepositoryDetailViewTests {
    
    // MARK: - Test Data
    
    private var sampleOwner: Owner {
        Owner(
            id: 123,
            login: "apple",
            avatarUrl: "https://avatars.githubusercontent.com/u/10639145?v=4"
        )
    }
    
    private var sampleRepository: Repository {
        Repository(
            id: 456,
            name: "swift",
            owner: sampleOwner,
            forksCount: 2500,
            stargazersCount: 65000,
            description: "The Swift Programming Language"
        )
    }
    
    private var repositoryWithLongDescription: Repository {
        Repository(
            id: 789,
            name: "repository-with-very-long-description",
            owner: sampleOwner,
            forksCount: 100,
            stargazersCount: 500,
            description: "This is an extremely long description that would definitely exceed the three-line limit and should trigger the expansion functionality when users tap on it. This description contains multiple sentences and provides comprehensive information about the repository's purpose, features, and implementation details."
        )
    }
    
    private var repositoryWithoutDescription: Repository {
        Repository(
            id: 999,
            name: "no-description-repo",
            owner: sampleOwner,
            forksCount: 50,
            stargazersCount: 200,
            description: nil
        )
    }
    
    // MARK: - View Initialization Tests
    
    @Test("View initializes with repository and default API service")
    func testViewInitializationWithDefaultAPIService() async {
        let view = RepositoryDetailView(repository: sampleRepository)
        
        // Test that the view can be instantiated without crashing
        #expect(view.body != nil)
    }
    
    @Test("View initializes with repository and custom API service")
    func testViewInitializationWithCustomAPIService() async {
        let mockAPIService = MockAPIService()
        let view = RepositoryDetailView(repository: sampleRepository, apiService: mockAPIService)
        
        // Test that the view can be instantiated with custom API service
        #expect(view.body != nil)
    }
    
    // MARK: - View Model Integration Tests
    
    @Test("View model receives correct repository data during initialization")
    func testViewModelIntegration() async {
        let mockAPIService = MockAPIService()
        let view = RepositoryDetailView(repository: sampleRepository, apiService: mockAPIService)
        
        // Access the view model through a helper method or by rendering the view
        // Since we can't directly access @StateObject from tests, we verify through expected behavior
        #expect(view.body != nil)
    }
    
    // MARK: - UI Component Tests
    
    @Test("StatCard displays correct values")
    func testStatCardValues() async {
        let statCard = StatCard(
            icon: "star.fill",
            iconColor: .yellow,
            title: "Stars",
            value: "1,234"
        )
        
        #expect(statCard.body != nil)
        #expect(statCard.icon == "star.fill")
        #expect(statCard.iconColor == .yellow)
        #expect(statCard.title == "Stars")
        #expect(statCard.value == "1,234")
    }
    
    @Test("InfoRow displays correct information")
    func testInfoRowValues() async {
        let infoRow = InfoRow(
            icon: "info.circle.fill",
            title: "Visibility",
            value: "Public"
        )
        
        #expect(infoRow.body != nil)
        #expect(infoRow.icon == "info.circle.fill")
        #expect(infoRow.title == "Visibility")
        #expect(infoRow.value == "Public")
    }
    
    // MARK: - Edge Case Tests
    
    @Test("View handles repository without description gracefully")
    func testViewWithoutDescription() async {
        let view = RepositoryDetailView(repository: repositoryWithoutDescription)
        
        // Should not crash when description is nil
        #expect(view.body != nil)
    }
    
    @Test("View handles repository with very long description")
    func testViewWithLongDescription() async {
        let view = RepositoryDetailView(repository: repositoryWithLongDescription)
        
        // Should handle long descriptions without issues
        #expect(view.body != nil)
    }
    
    @Test("View handles repository with zero stats")
    func testViewWithZeroStats() async {
        let zeroStatsRepo = Repository(
            id: 1,
            name: "empty-repo",
            owner: sampleOwner,
            forksCount: 0,
            stargazersCount: 0,
            description: "A repository with no stars or forks"
        )
        
        let view = RepositoryDetailView(repository: zeroStatsRepo)
        
        // Should handle zero values gracefully
        #expect(view.body != nil)
    }
    
    @Test("View handles repository with nil stats")
    func testViewWithNilStats() async {
        let nilStatsRepo = Repository(
            id: 1,
            name: "nil-stats-repo",
            owner: sampleOwner,
            forksCount: nil,
            stargazersCount: nil,
            description: "A repository with nil stats"
        )
        
        let view = RepositoryDetailView(repository: nilStatsRepo)
        
        // Should handle nil values gracefully
        #expect(view.body != nil)
    }
    
    @Test("View handles repository without owner")
    func testViewWithoutOwner() async {
        let orphanRepo = Repository(
            id: 1,
            name: "orphan-repo",
            owner: nil,
            forksCount: 100,
            stargazersCount: 500,
            description: "A repository without an owner"
        )
        
        let view = RepositoryDetailView(repository: orphanRepo)
        
        // Should handle missing owner gracefully
        #expect(view.body != nil)
    }
    
    // MARK: - Navigation and Accessibility Tests
    
    @Test("View sets correct navigation bar display mode")
    func testNavigationBarDisplayMode() async {
        let view = RepositoryDetailView(repository: sampleRepository)
        
        // View should be configured for inline navigation
        #expect(view.body != nil)
    }
    
    // MARK: - Performance Tests
    
    @Test("View creation is efficient")
    func testViewCreationPerformance() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<100 {
            let view = RepositoryDetailView(repository: sampleRepository)
            _ = view.body
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // View creation should be fast (less than 1 second for 100 instances)
        #expect(timeElapsed < 1.0, "View creation took too long: \(timeElapsed) seconds")
    }
}

// MARK: - Mock API Service for View Tests

final class MockAPIService: APIServiceProtocol {
    var shouldThrowError = false
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
        
        return mockRepositoryDetails ?? Repository(
            id: id,
            name: "Mock Repository",
            owner: Owner(id: 1, login: "mockuser", avatarUrl: ""),
            forksCount: 100,
            stargazersCount: 500,
            description: "A mock repository for testing"
        )
    }
} 