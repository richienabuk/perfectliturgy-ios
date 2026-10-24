import Foundation

enum PackHTTPError: Error, Equatable {
    case status(Int)
    case transport
}

protocol PackTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct LivePackTransport: PackTransport {
    var session: URLSession = .shared

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

struct PackClient {
    var transport: any PackTransport
    var apiBase: URL
    var token: String?

    func catalog() async throws -> [PackRecord] {
        var page = 1
        var collected: [PackRecord] = []
        var seen: Set<String> = []
        while page <= 30 {
            let envelope = try await fetchPage(page)
            for pack in envelope.data where seen.insert(pack.packId).inserted {
                collected.append(pack)
            }
            if envelope.data.isEmpty || collected.count >= envelope.total {
                break
            }
            page += 1
        }
        return collected
    }

    func download(packId: String) async throws -> Data {
        let url = apiBase
            .appending(path: "v1")
            .appending(path: "packs")
            .appending(path: packId)
            .appending(path: "download")
        return try await fetch(url)
    }

    private func fetchPage(_ page: Int) async throws -> PackListEnvelope {
        let base = apiBase.appending(path: "v1").appending(path: "packs")
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw PackHTTPError.transport
        }
        components.queryItems = [URLQueryItem(name: "page", value: String(page))]
        guard let url = components.url else { throw PackHTTPError.transport }
        let data = try await fetch(url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(PackListEnvelope.self, from: data)
        } catch {
            throw PackHTTPError.transport
        }
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("__Secure-neon-auth.session_token=\(token)", forHTTPHeaderField: "Cookie")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch let error as PackHTTPError {
            throw error
        } catch {
            throw PackHTTPError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw PackHTTPError.transport }
        guard (200..<300).contains(http.statusCode) else { throw PackHTTPError.status(http.statusCode) }
        return data
    }
}
