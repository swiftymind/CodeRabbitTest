import SwiftUI
import Shimmer

struct GithubHomeView: View {
    @StateObject var viewModel = GithubHomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Category selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(RepoCategory.allCases, id: \.self) { category in
                                CategoryButton(
                                    title: category.rawValue,
                                    isSelected: viewModel.selectedCategory == category
                                ) {
                                    viewModel.selectedCategory = category
                                    Task {
                                        await viewModel.fetchRepositories()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Main content
                    if viewModel.displayState == .loading {
                        ShimmerRepositoryList()
                    } else if case .error(let message) = viewModel.displayState {
                        ContentErrorView(message: message)
                    } else {
                        RepositoriesList(
                            repositories: viewModel.searchResults.isEmpty ? viewModel.repositories : viewModel.searchResults
                        )
                    }
                }
            }
            .navigationTitle("GitHub Explorer")
            .searchable(text: $viewModel.searchText, prompt: "Search repositories...")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.searchRepositories()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section(header: Text("Sort by Stars")) {
                            Button("Most Stars") {
                                viewModel.sortRepositoriesByStars(ascending: false)
                            }
                            Button("Least Stars") {
                                viewModel.sortRepositoriesByStars(ascending: true)
                            }
                        }

                        Section(header: Text("Sort by Forks")) {
                            Button("Most Forks") {
                                viewModel.sortRepositoriesByForks(ascending: false)
                            }
                            Button("Least Forks") {
                                viewModel.sortRepositoriesByForks(ascending: true)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .task {
                await viewModel.fetchRepositories()
            }
        }
    }
}

// MARK: - Supporting Views

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? .blue : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ContentLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressView()
            Text("Loading repositories...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 4)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 2, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct ContentErrorView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("Error Loading Data")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 4)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 2, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct RepositoriesList: View {
    let repositories: [Repository]

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(repositories) { repo in
                NavigationLink(destination: RepositoryDetailView(repository: repo)) {
                    RepositoryRow(repository: repo)
                }
            }

            if repositories.isEmpty {
                EmptyResultsView()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct EmptyResultsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Repositories Found")
                .font(.headline)

            Text("Try adjusting your search or selecting a different category")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 4)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 2, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct RepositoryRow: View {
    let repository: Repository

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Repository Name and Stats
            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name ?? "Unnamed Repository")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let description = repository.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            // Stats Row
            HStack(spacing: 16) {
                Label {
                    Text(formatNumber(repository.stargazersCount ?? 0))
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
                .foregroundStyle(.secondary)

                Label {
                    Text(formatNumber(repository.forksCount ?? 0))
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "tuningfork")
                        .foregroundStyle(.blue)
                }
                .foregroundStyle(.secondary)

                if repository.isPopular {
                    Label("Popular", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.gradient)
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 4)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 2, x: 0, y: 2)
    }

    private func formatNumber(_ number: Int) -> String {
        let thousand = 1000
        let million = thousand * 1000

        switch number {
        case million...:
            return String(format: "%.1fM", Double(number) / Double(million))
        case thousand...:
            return String(format: "%.1fK", Double(number) / Double(thousand))
        default:
            return "\(number)"
        }
    }
}

// MARK: - Shimmer Views

struct ShimmerRepositoryList: View {
    let numberOfShimmerCards = 5

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<numberOfShimmerCards, id: \.self) { _ in
                ShimmerRepositoryRow()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ShimmerRepositoryRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Repository Name and Description
            VStack(alignment: .leading, spacing: 8) {
                // Name
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 20)
                    .shimmering()

                // Description
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .shimmering()

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 16)
                    .shimmering()
            }

            // Stats Row
            HStack(spacing: 16) {
                // Stars
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 20)
                    .shimmering()

                // Forks
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 20)
                    .shimmering()

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 4)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 2, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        GithubHomeView()
    }
}
