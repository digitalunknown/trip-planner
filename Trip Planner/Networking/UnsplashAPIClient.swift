import Foundation

struct UnsplashAPIClient {
    enum ClientError: LocalizedError {
        case invalidResponse
        case http(status: Int, body: String)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from server."
            case .http(let status, let body):
                if body.isEmpty { return "Server error (\(status))." }
                return "Server error (\(status)): \(body)"
            }
        }
    }
    
    let baseURL: URL
    
    init(baseURL: URL = URL(string: "https://trip-planner-ai-proxy.vercel.app")!) {
        self.baseURL = baseURL
    }
    
    func searchPhotos(query: String, page: Int = 1, perPage: Int = 30) async throws -> UnsplashSearchResponse {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/api/unsplash/search"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "per_page", value: String(min(30, max(1, perPage))))
        ]
        guard let url = comps?.url else { throw ClientError.invalidResponse }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(status: http.statusCode, body: body)
        }
        
        return try JSONDecoder().decode(UnsplashSearchResponse.self, from: data)
    }
    
    func trackDownload(downloadLocation: String) async throws {
        let url = baseURL.appendingPathComponent("/api/unsplash/track-download")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(UnsplashTrackDownloadRequest(download_location: downloadLocation))
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) || http.statusCode == 204 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(status: http.statusCode, body: body)
        }
    }
}

struct UnsplashSearchResponse: Codable, Hashable {
    var query: String
    var page: Int
    var per_page: Int
    var total: Int?
    var total_pages: Int?
    var results: [UnsplashPhoto]
}

struct UnsplashPhoto: Codable, Hashable, Identifiable {
    var id: String
    var width: Int?
    var height: Int?
    var color: String?
    var blur_hash: String?
    var description: String?
    var urls: UnsplashPhotoURLs
    var user: UnsplashPhotoUser
    var unsplash_url: String
    var download_location: String?
}

struct UnsplashPhotoURLs: Codable, Hashable {
    var small: String?
    var regular: String?
}

struct UnsplashPhotoUser: Codable, Hashable {
    var name: String
    var profile_url: String
}

private struct UnsplashTrackDownloadRequest: Codable {
    let download_location: String
}

