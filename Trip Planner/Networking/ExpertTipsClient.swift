import Foundation

struct ExpertTipsClient {
    static let defaultEndpoint = URL(string: "https://trip-planner-ai-proxy.vercel.app/api/expert-tips")!
    
    let endpoint: URL
    private let session: URLSession
    
    init(
        endpoint: URL = ExpertTipsClient.defaultEndpoint,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }
    
    enum ClientError: LocalizedError {
        case invalidResponse
        case http(status: Int, body: String)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid Expert Tips feed response."
            case .http(let status, _):
                return "Server error (\(status))."
            }
        }
    }
    
    /// - Parameter forceRefresh: When true, bypass URL cache so Vercel edits show up immediately.
    func fetchFeed(forceRefresh: Bool = false) async throws -> ExpertTipsFeedResponse {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        if forceRefresh {
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
        
        return try JSONDecoder().decode(ExpertTipsFeedResponse.self, from: data)
    }
}
