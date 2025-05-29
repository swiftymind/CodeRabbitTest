import UIKit
import Combine

class SearchViewController: UIViewController {
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    private var repositories: [Repository] = []
    private var cancellables = Set<AnyCancellable>()
    private let repositoryService = RepositoryService()
    private var currentPage = 1
    private var isLoading = false
    private var hasMoreData = true

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupSearchBar()
        setupRefreshControl()
    }

    private func setupUI() {
        title = "GitHub Explorer"
        navigationController?.navigationBar.prefersLargeTitles = true

        // Configure for dark mode support
        view.backgroundColor = UIColor.systemBackground
        tableView.backgroundColor = UIColor.systemBackground
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RepositoryTableViewCell.self, forCellReuseIdentifier: "RepositoryCell")

        // Accessibility
        tableView.accessibilityLabel = "Repository search results"
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search GitHub repositories..."
        searchBar.accessibilityLabel = "Search repositories"

        // Real-time search with debouncing
        searchBar.searchTextField.publisher(for: \.text)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.performSearch(query: searchText ?? "")
            }
            .store(in: &cancellables)
    }

    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }

    @objc private func refreshData() {
        guard let query = searchBar.text, !query.isEmpty else {
            tableView.refreshControl?.endRefreshing()
            return
        }

        currentPage = 1
        hasMoreData = true
        repositories.removeAll()
        tableView.reloadData()
        performSearch(query: query)
    }

    private func performSearch(query: String) {
        guard !query.isEmpty, !isLoading else { return }

        isLoading = true
        showLoadingIndicator()

        repositoryService.searchRepositories(query: query, page: currentPage)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.hideLoadingIndicator()
                    self?.isLoading = false

                    if case .failure(let error) = completion {
                        self?.showErrorAlert(error: error)
                    }
                },
                receiveValue: { [weak self] response in
                    if self?.currentPage == 1 {
                        self?.repositories = response.items
                    } else {
                        self?.repositories.append(contentsOf: response.items)
                    }

                    self?.hasMoreData = response.items.count >= 30 // GitHub API page size
                    self?.tableView.reloadData()
                    self?.tableView.refreshControl?.endRefreshing()
                }
            )
            .store(in: &cancellables)
    }

    private func loadMoreRepositories() {
        guard hasMoreData, !isLoading, let query = searchBar.text, !query.isEmpty else { return }

        currentPage += 1
        performSearch(query: query)
    }

    private func showLoadingIndicator() {
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
    }

    private func hideLoadingIndicator() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
    }

    private func showErrorAlert(error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return repositories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RepositoryCell", for: indexPath) as! RepositoryTableViewCell
        let repository = repositories[indexPath.row]
        cell.configure(with: repository)

        // Load more data when approaching end
        if indexPath.row == repositories.count - 5 {
            loadMoreRepositories()
        }

        return cell
    }
}

// MARK: - UITableViewDelegate
extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let repository = repositories[indexPath.row]
        // Navigate to repository detail view
        let detailVC = RepositoryDetailViewController(repository: repository)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        repositories.removeAll()
        tableView.reloadData()
    }
}