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
    
    /// - Parameter forceRefresh: When true (pull-to-refresh), bypass URL cache so edits on Vercel show up immediately.
    func fetchFeed(forceRefresh: Bool = false) async throws -> ExploreFeedResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = forceRefresh ? .reloadIgnoringLocalCacheData : .reloadRevalidatingCacheData
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
