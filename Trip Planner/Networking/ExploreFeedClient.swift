import Foundation

struct ExploreFeedClient {
    static let defaultEndpoint = URL(string: "https://trip-planner-ai-proxy.vercel.app/api/explore")!
    
    let endpoint: URL
    private let session: URLSession
    
    init(
        endpoint: URL = ExploreFeedClient.defaultEndpoint,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }
    
    enum ClientError: LocalizedError {
        case invalidResponse
        case http(status: Int, body: String)
        case emptyFeed
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid Explore feed response."
            case .http(let status, let body):
                if body.isEmpty { return "Server error (\(status))." }
                return "Server error (\(status))."
            case .emptyFeed:
                return "Explore feed was empty."
            }
        }
    }
    
    /// - Parameter forceRefresh: When true, bypass URL cache so Vercel edits show up immediately.
    func fetchFeed(forceRefresh: Bool = false) async throws -> ExploreFeedResponse {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        if forceRefresh {
            // Cache-buster for intermediaries that ignore Cache-Control.
            var items = components?.queryItems ?? []
            items.append(URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970 * 1000))))
            components?.queryItems = items
        }
        guard let url = components?.url ?? Optional(endpoint) else {
            throw ClientError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if forceRefresh {
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        } else {
            request.cachePolicy = .reloadRevalidatingCacheData
        }
        request.timeoutInterval = 20
        
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(status: http.statusCode, body: body)
        }
        
        let decoded = try JSONDecoder().decode(ExploreFeedResponse.self, from: data)
        guard !decoded.picks.isEmpty else { throw ClientError.emptyFeed }
        return decoded
    }
}
