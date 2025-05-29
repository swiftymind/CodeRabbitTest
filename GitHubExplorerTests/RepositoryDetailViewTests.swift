import SwiftUI
import Testing
@testable import GitHubExplorer

struct RepositoryDetailViewTests {

    @Test func testRepositoryDetailViewInitialization() {
        // Arrange
        let repository = Repository(
            id: 123,
            name: "test-repo",
            owner: Owner(id: 1, login: "testuser", avatarUrl: "https://example.com/avatar.jpg"),
            forksCount: 50,
            stargazersCount: 100,
            description: "Test repository description"
        )

        // Act
        let view = RepositoryDetailView(repository: repository)

        // Assert
        #expect(view.viewModel.repositoryName == "test-repo")
        #expect(view.viewModel.ownerName == "testuser")
        #expect(view.viewModel.starCount == "100")
        #expect(view.viewModel.forkCount == "50")
    }

    // Test Stat Card and Info Row Views

    
    @Test func testStatCardView() {
        // Act
        let view = StatCard(
            icon: "star.fill",
            iconColor: .yellow,
            title: "Stars",
            value: "100"
        )

        // Assert - Verify it renders without crashing
        _ = view.body
    }

    @Test func testInfoRowView() {
        // Act
        let view = InfoRow(
            icon: "info.circle.fill",
            title: "Visibility",
            value: "Public"
        )

        // Assert - Verify it renders without crashing
        _ = view.body
    }
}

// Test the preview provider as well
struct RepositoryDetailViewPreviewTests {

    @Test func testPreviewInitialization() {
        // Using type-erased AnyView to access the preview
        let previewContent = Preview_RepositoryDetailView_Previews().content

        // Assert the preview doesn't crash on initialization
        _ = previewContent
    }
}
