import SwiftUI

struct GithubRowView: View {
    var repository: Repository

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row with avatar and repository name
            HStack(alignment: .center, spacing: 16) {
                AvatarView(
                    name: repository.owner?.login ?? "",
                    url: repository.owner?.avatarUrl ?? "",
                    owner: repository.owner ?? Owner(id: 0, login: "", avatarUrl: "")
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(repository.name ?? "")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let ownerLogin = repository.owner?.login {
                        Text(ownerLogin)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Description
            if let description = repository.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Stats row
            HStack(spacing: 16) {
                // Stars
                Label {
                    Text("\(repository.stargazersCount ?? 0)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }

                // Forks
                Label {
                    Text("\(repository.forksCount ?? 0)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "tuningfork")
                        .foregroundStyle(.blue)
                }

                Spacer()

                // Popular badge if applicable
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
        .padding()
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

#Preview {
    List {
        GithubRowView(repository: Repository(
            id: 1,
            name: "Alamofire",
            owner: Owner(
                id: 1,
                login: "Alamofire",
                avatarUrl: "https://avatars.githubusercontent.com/u/1?v=4"
            ),
            forksCount: 7606,
            stargazersCount: 39500,
            description: "Elegant HTTP Networking in Swift"
        ))
    }
    .listStyle(.plain)
}

//
//  AvatarView.swift
//  GithubSwiftUI
//

import SwiftUI

struct AvatarView: View {
    var name: String
    var url: String
    var owner: Owner

    var body: some View {
        NavigationLink(destination: OwnerDetailView(owner: owner)) {
            AsyncImage(url: URL(string: url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }
}

#Preview {
    AvatarView(
        name: "Test User",
        url: "https://avatars.githubusercontent.com/u/1?v=4",
        owner: Owner(id: 1, login: "Test User", avatarUrl: "https://avatars.githubusercontent.com/u/1?v=4")
    )
}
