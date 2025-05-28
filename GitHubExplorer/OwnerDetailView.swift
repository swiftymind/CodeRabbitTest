import SwiftUI
import Shimmer

struct OwnerDetailView: View {
    @StateObject private var viewModel: OwnerDetailViewModel
    private let owner: Owner

    private let columns = [
        GridItem(.flexible(minimum: 160), spacing: 16),
        GridItem(.flexible(minimum: 160), spacing: 16)
    ]

    init(owner: Owner, apiService: APIServiceProtocol = APIServiceImpl()) {
        self.owner = owner
        _viewModel = StateObject(wrappedValue: OwnerDetailViewModel(owner: owner, apiService: apiService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ShimmerOwnerProfile()
                } else {
                    ownerProfileSection
                }

                repositoriesSection
            }
            .padding()
        }
        .navigationTitle("Owner Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchOwnerRepositories()
        }
    }

    private var ownerProfileSection: some View {
        VStack(spacing: 20) {
            // Owner Avatar and Info
            AsyncImage(url: URL(string: owner.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
            } placeholder: {
                ProgressView()
                    .frame(width: 150, height: 150)
            }

            Text(viewModel.ownerName)
                .font(.title)
                .bold()

            // Stats Section
            HStack(spacing: 40) {
                VStack {
                    Text("\(viewModel.repositoryCount)")
                        .font(.title2)
                        .bold()
                    Text("Repositories")
                        .font(.subheadline)
                }

                VStack {
                    Text("\(viewModel.totalStars)")
                        .font(.title2)
                        .bold()
                    Text("Total Stars")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }

    private var repositoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Popular Repositories")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.isLoading {
                ShimmerRepositoryGrid()
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.sortedRepositories) { repo in
                        NavigationLink(destination: RepositoryDetailView(repository: repo)) {
                            RepositoryGridItem(repository: repo)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Shimmer Views

struct ShimmerOwnerProfile: View {
    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 150, height: 150)
                .shimmering()

            // Username
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 200, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shimmering()

            // Stats Section
            HStack(spacing: 40) {
                // Repositories Count
                VStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 30)
                        .shimmering()

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 20)
                        .shimmering()
                }

                // Total Stars
                VStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 30)
                        .shimmering()

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 20)
                        .shimmering()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct ShimmerRepositoryGrid: View {
    let numberOfItems = 4

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(minimum: 160), spacing: 16),
            GridItem(.flexible(minimum: 160), spacing: 16)
        ], spacing: 16) {
            ForEach(0..<numberOfItems, id: \.self) { _ in
                ShimmerGridItem()
            }
        }
        .padding(.horizontal)
    }
}

struct ShimmerGridItem: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
                .shimmering()

            // Description
            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .shimmering()

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 16)
                    .shimmering()
            }

            Spacer()

            // Stats
            HStack(spacing: 16) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 20)
                    .shimmering()

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 20)
                    .shimmering()

                Spacer()
            }
        }
        .frame(height: 150)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.1), radius: 8, x: 0, y: 4)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 2, x: 0, y: 2)
    }
}

struct RepositoryGridItem: View {
    let repository: Repository

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Repository Name
                Text(repository.name ?? "")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Description
                if let description = repository.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 8) {
                // Stats
                HStack(spacing: 16) {
                    Label {
                        Text(formatNumber(repository.stargazersCount ?? 0))
                            .font(.caption)
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    .layoutPriority(1)

                    Label {
                        Text(formatNumber(repository.forksCount ?? 0))
                            .font(.caption)
                    } icon: {
                        Image(systemName: "tuningfork")
                            .foregroundStyle(.blue)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 0)
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
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
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
