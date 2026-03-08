import Foundation

enum AppHTTPError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case unexpectedStatusCode(Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "后端接口未配置"
        case .invalidResponse:
            return "服务端响应无效"
        case .unexpectedStatusCode(let code):
            return "服务端返回异常状态码: \(code)"
        case .decodingFailed:
            return "服务端数据解析失败"
        }
    }
}

struct AppHTTPClient {
    private let session: URLSession

    nonisolated init(timeout: TimeInterval = 20) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration)
    }

    func get<T: Decodable>(_ url: URL, decode type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return try await perform(request, decode: type)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ url: URL,
        body: Body,
        decode type: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request, decode: type)
    }

    private func perform<T: Decodable>(_ request: URLRequest, decode type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppHTTPError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw AppHTTPError.unexpectedStatusCode(httpResponse.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppHTTPError.decodingFailed
        }
    }
}
