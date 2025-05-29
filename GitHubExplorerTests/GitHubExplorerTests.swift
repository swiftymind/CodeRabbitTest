//
//  GitHubExplorerTests.swift
//  GitHubExplorerTests
//
//  Created by Muralidharan Kathiresan on 26/05/2025.
//

import Testing
@testable import GitHubExplorer

// Mock API Service for testing
class MockAPIService: APIServiceProtocol {
    var mockRepositories: [Repository] = []
    var shouldThrowError = false

    func fetchRepositories(category: RepoCategory) async throws -> [Repository] {
        if shouldThrowError {
            throw APIError.badURL
        }
        return mockRepositories
    }

    func searchRepositories(query: String) async throws -> [Repository] {
        if shouldThrowError {
            throw APIError.badURL
        }
        return mockRepositories.filter { ($0.name ?? "").contains(query) }
    }

    func fetchRepositoryDetails(id: Int) async throws -> Repository {
        if shouldThrowError {
            throw APIError.badURL
        }
        if let repository = mockRepositories.first(where: { $0.id == id }) {
            return repository
        }
        throw APIError.decodingError
    }
}

struct GitHubExplorerTests {
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
}

// Repository Model Tests
struct RepositoryTests {
    @Test func testStarRating() {
        // Arrange
        let repository1 = Repository(
            id: 1,
            name: "Test Repo 1",
            owner: nil,
            forksCount: 0,
            stargazersCount: 0,
            description: nil
        )

        let repository2 = Repository(
            id: 2,
            name: "Test Repo 2",
            owner: nil,
            forksCount: 0,
            stargazersCount: 2000,
            description: nil
        )

        let repository3 = Repository(
            id: 3,
            name: "Test Repo 3",
            owner: nil,
            forksCount: 0,
            stargazersCount: 12000,
            description: nil
        )

        // Act & Assert
        #expect(repository1.starRating == "")
        #expect(repository2.starRating == "⭐")
        #expect(repository3.starRating == "⭐⭐⭐⭐⭐")
    }

    @Test func testIsPopular() {
        // Arrange
        let unpopularRepo = Repository(
            id: 1,
            name: "Unpopular",
            owner: nil,
            forksCount: 0,
            stargazersCount: 999,
            description: nil
        )

        let popularRepo = Repository(
            id: 2,
            name: "Popular",
            owner: nil,
            forksCount: 0,
            stargazersCount: 1000,
            description: nil
        )

        // Act & Assert
        #expect(!unpopularRepo.isPopular)
        #expect(popularRepo.isPopular)
    }

    @Test func testFormattedForks() {
        // Arrange
        let repository = Repository(
            id: 1,
            name: "Test Repo",
            owner: nil,
            forksCount: 42,
            stargazersCount: 0,
            description: nil
        )

        // Act & Assert
        #expect(repository.formattedForks == "42 forks")
    }
}

// ViewModel Tests
struct RepositoryDetailViewModelTests {
    @Test func testComputedProperties() {
        // Arrange
        let repository = Repository(
            id: 123,
            name: "swift-repo",
            owner: Owner(id: 1, login: "swift-dev", avatarUrl: "https://example.com/avatar.jpg"),
            forksCount: 42,
            stargazersCount: 1500,
            description: "A Swift repository for testing."
        )

        let viewModel = RepositoryDetailViewModel(repository: repository)

        // Act & Assert
        #expect(viewModel.ownerName == "swift-dev")
        #expect(viewModel.repositoryName == "swift-repo")
        #expect(viewModel.description == "A Swift repository for testing.")
        #expect(viewModel.starCount == "1500")
        #expect(viewModel.forkCount == "42")
        #expect(viewModel.isPopular)
        #expect(viewModel.ownerAvatarUrl == "https://example.com/avatar.jpg")
        #expect(viewModel.repositoryUrl.absoluteString == "https://github.com/swift-dev/swift-repo")
    }

    @Test func testRefreshRepositoryDetails() async {
        // Arrange
        let initialRepo = Repository(
            id: 123,
            name: "initial-repo",
            owner: Owner(id: 1, login: "dev", avatarUrl: "https://example.com/avatar.jpg"),
            forksCount: 10,
            stargazersCount: 100,
            description: "Initial description"
        )

        let updatedRepo = Repository(
            id: 123,
            name: "updated-repo",
            owner: Owner(id: 1, login: "dev", avatarUrl: "https://example.com/avatar.jpg"),
            forksCount: 20,
            stargazersCount: 200,
            description: "Updated description"
        )

        let mockAPIService = MockAPIService()
        mockAPIService.mockRepositories = [updatedRepo]

        let viewModel = RepositoryDetailViewModel(repository: initialRepo, apiService: mockAPIService)

        // Act
        await viewModel.refreshRepositoryDetails()

        // Assert
        #expect(viewModel.repositoryName == "updated-repo")
        #expect(viewModel.starCount == "200")
        #expect(viewModel.forkCount == "20")
        #expect(viewModel.description == "Updated description")
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func testRefreshRepositoryDetailsError() async {
        // Arrange
        let repository = Repository(
            id: 123,
            name: "test-repo",
            owner: Owner(id: 1, login: "dev", avatarUrl: "https://example.com/avatar.jpg"),
            forksCount: 10,
            stargazersCount: 100,
            description: "Test description"
        )

        let mockAPIService = MockAPIService()
        mockAPIService.shouldThrowError = true

        let viewModel = RepositoryDetailViewModel(repository: repository, apiService: mockAPIService)

        // Act
        await viewModel.refreshRepositoryDetails()

        // Assert
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Failed to refresh repository details") ?? false)
    }
}

// APIService Tests
struct APIServiceTests {
    @Test func testSearchRepositories() async throws {
        // Arrange
        let mockAPIService = MockAPIService()
        mockAPIService.mockRepositories = [
            Repository(id: 1, name: "swift-tools", owner: nil, forksCount: 0, stargazersCount: 0, description: nil),
            Repository(id: 2, name: "swift-algorithms", owner: nil, forksCount: 0, stargazersCount: 0, description: nil),
            Repository(id: 3, name: "vapor", owner: nil, forksCount: 0, stargazersCount: 0, description: nil)
        ]

        // Act
        let results = try await mockAPIService.searchRepositories(query: "swift")

        // Assert
        #expect(results.count == 2)
        #expect(results[0].name == "swift-tools")
        #expect(results[1].name == "swift-algorithms")
    }
}
