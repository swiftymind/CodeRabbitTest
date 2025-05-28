import SwiftUI

struct RepositoryDetailView: View {
    @StateObject private var viewModel: RepositoryDetailViewModel

    init(repository: Repository, apiService: APIServiceProtocol = APIServiceImpl()) {
        _viewModel = StateObject(wrappedValue: RepositoryDetailViewModel(repository: repository, apiService: apiService))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                VStack(alignment: .leading, spacing: 12) {
                    // Owner Info
                    HStack {
                        AvatarView(
                            name: viewModel.ownerName,
                            url: viewModel.ownerAvatarUrl,
                            owner: viewModel.repository.owner ?? Owner(id: 0, login: "", avatarUrl: "")
                        )
                        Text(viewModel.ownerName)
                            .font(.headline)
                        Spacer()

                        ShareLink(item: viewModel.repositoryUrl) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal)

                    // Repository Name
                    Text(viewModel.repositoryName)
                        .font(.title)
                        .bold()
                        .padding(.horizontal)

                    // Description
                    if let description = viewModel.description {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(viewModel.isDescriptionExpanded ? nil : 3)
                            .padding(.horizontal)
                            .onTapGesture {
                                withAnimation {
                                    viewModel.isDescriptionExpanded.toggle()
                                }
                            }
                    }
                }

                // Stats Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        icon: "star.fill",
                        iconColor: .yellow,
                        title: "Stars",
                        value: viewModel.starCount
                    )

                    StatCard(
                        icon: "tuningfork",
                        iconColor: .blue,
                        title: "Forks",
                        value: viewModel.forkCount
                    )
                }
                .padding(.horizontal)

                // Additional Info Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Repository Info")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        InfoRow(
                            icon: "info.circle.fill",
                            title: "Visibility",
                            value: "Public"
                        )

                        InfoRow(
                            icon: "star.circle.fill",
                            title: "Popularity",
                            value: viewModel.isPopular ? "Popular Repository" : "Regular Repository"
                        )
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Link(destination: viewModel.repositoryUrl) {
                        HStack {
                            Image(systemName: "globe")
                            Text("View on GitHub")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshRepositoryDetails()
        }
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(iconColor)

            Text(value)
                .font(.title2)
                .bold()

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 30)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .foregroundStyle(.primary)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))

        Divider()
            .padding(.leading, 56)
    }
}

#Preview {
    NavigationView {
        RepositoryDetailView(repository: Repository(
            id: 1,
            name: "Alamofire",
            owner: Owner(
                id: 1,
                login: "Alamofire",
                avatarUrl: "https://avatars.githubusercontent.com/u/1?v=4"
            ),
            forksCount: 7606,
            stargazersCount: 39500,
            description: "Elegant HTTP Networking in Swift. The most widely used HTTP networking library for iOS and macOS applications, built on top of URLSession. Provides an elegant interface for making HTTP requests, handling responses, and managing network connectivity."
        ))
    }
}
