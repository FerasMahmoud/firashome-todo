import Foundation

/// Talks to the Firashome Tasks API (any backend URL). Offline-first: the app
/// keeps working locally via SwiftData; this layer pushes/pulls on demand.
/// Default backend is the Tailscale-Funnel public URL.
struct SyncClient {
    static let defaultBaseURL = "https://firashome-tasks-api.fly.dev"

    let baseURL: String
    let token: String?

    init(baseURL: String = defaultBaseURL, token: String? = nil) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")).isEmpty
            ? Self.defaultBaseURL
            : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.token = token
    }

    private func url(_ path: String) -> URL { URL(string: baseURL + path)! }
    private var auth: [String: String] { token.map { ["Authorization": "Bearer \($0)"] } ?? [:] }

    // MARK: - Auth
    struct AuthResponse: Decodable { let access_token: String; let user: UserDTO }
    struct UserDTO: Decodable { let id: String; let email: String; let name: String }

    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        try await post("/auth/register", body: ["email": email, "password": password, "name": name])
    }
    func login(email: String, password: String) async throws -> AuthResponse {
        try await post("/auth/login", body: ["email": email, "password": password])
    }

    // MARK: - Sync (push everything, pull server state)
    struct LabelDTO: Codable { var id: String?; var name: String; var color_hex: String }
    struct ProjectDTO: Codable { var id: String?; var name: String; var color_hex: String; var order: Int; var is_favorite: Bool }
    struct TaskDTO: Codable {
        var id: String?; var title: String; var note: String; var priority: Int; var order: Int
        var due_date: String?; var completed_at: String?; var project_id: String?; var label_ids: [String]
    }
    struct SyncResponse: Decodable {
        let server_time: String
        let tasks: [RemoteTask]; let projects: [RemoteProject]; let labels: [RemoteLabel]
    }
    struct RemoteTask: Decodable { let id: String; let title: String; let note: String?; let priority: Int; let order: Int; let due_date: String?; let completed_at: String?; let project_id: String?; let label_ids: [String]? }
    struct RemoteProject: Decodable { let id: String; let name: String; let color_hex: String; let order: Int; let is_favorite: Bool }
    struct RemoteLabel: Decodable { let id: String; let name: String; let color_hex: String }

    func push(tasks: [TaskDTO], projects: [ProjectDTO], labels: [LabelDTO]) async throws -> SyncResponse {
        let body: [String: Any] = [
            "tasks": try dictArray(tasks), "projects": try dictArray(projects), "labels": try dictArray(labels)
        ]
        return try await postBody("/sync/push", body: body, authed: true)
    }
    func pull() async throws -> SyncResponse {
        var req = URLRequest(url: url("/sync/pull"))
        req.allHTTPHeaderFields = auth
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp)
        return try Self.decoder.decode(SyncResponse.self, from: data)
    }

    // MARK: - Plumbing
    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        try await postBody(path, body: body, authed: false)
    }
    private func postBody<T: Decodable>(_ path: String, body: [String: Any], authed: Bool) async throws -> T {
        var req = URLRequest(url: url(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authed { req.allHTTPHeaderFields = auth }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try Self.check(resp)
        return try Self.decoder.decode(T.self, from: data)
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    static func check(_ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else { throw SyncError.badResponse }
        if !(200..<300).contains(http.statusCode) {
            throw SyncError.http(http.statusCode)
        }
    }
    private func dictArray<T: Encodable>(_ items: [T]) throws -> [[String: Any]] {
        try items.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as! [String: Any] }
    }
}

enum SyncError: Error, LocalizedError {
    case badResponse, http(Int)
    var errorDescription: String? {
        switch self {
        case .badResponse: return "No response from server"
        case .http(let c): return "Server error (\(c))"
        }
    }
}
