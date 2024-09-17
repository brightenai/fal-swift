import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

extension HTTPURLResponse {
    /// Returns `true` if `statusCode` is in range 200...299.
    /// Otherwise `false`.
    var isSuccessful: Bool {
        200 ... 299 ~= statusCode
    }
}

extension Client {
    func sendRequest(to urlString: String, input: Data?, queryParams: [String: Any]? = nil, options: RunOptions) async throws -> Data {
        guard var url = URL(string: urlString) else {
            throw FalError.invalidUrl(url: urlString)
        }

        if let queryParams,
           !queryParams.isEmpty,
           var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        {
            urlComponents.queryItems = queryParams.map {
                URLQueryItem(name: $0.key, value: String(describing: $0.value))
            }
            url = urlComponents.url ?? url
        }

        let targetUrl = url
        if let requestProxy = config.requestProxy {
            guard let proxyUrl = URL(string: requestProxy) else {
                throw FalError.invalidUrl(url: requestProxy)
            }
            url = proxyUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = options.httpMethod.rawValue.uppercased()
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(userAgent, forHTTPHeaderField: "user-agent")

        // setup credentials if available
        let credentials = config.credentials.description
        if !credentials.isEmpty {
            request.setValue("Key \(config.credentials.description)", forHTTPHeaderField: "authorization")
        }

        // setup the request proxy if available
        if config.requestProxy != nil {
            request.setValue(targetUrl.absoluteString, forHTTPHeaderField: "x-fal-target-url")
        }

        if input != nil, options.httpMethod != .get {
            request.httpBody = input
        }
        let (data, response) = try await URLSession.shared.asyncData(from: request)
        try checkResponseStatus(for: response, withData: data)
        return data
    }

    func sharedData(for request:URLRequest) async throws  -> (Data, URLResponse)
    {
//        #if os(Linux)
        return try await URLSession.shared.asyncData(from: request)
//        #else
//        return try await URLSession.shared.data(for: request)
//        #endif
    }
    
    func checkResponseStatus(for response: URLResponse, withData data: Data) throws {
        guard response is HTTPURLResponse else {
            throw FalError.invalidResultFormat
        }
        if let httpResponse = response as? HTTPURLResponse, !httpResponse.isSuccessful {
            let errorPayload = try? Payload.create(fromJSON: data)
            let statusCode = httpResponse.statusCode
            let message = errorPayload?["detail"].stringValue
                ?? errorPayload?.stringValue
                ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
            throw FalError.httpError(
                status: statusCode,
                message: message,
                payload: errorPayload
            )
        }
    }

    var userAgent: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "fal.ai/swift-client 0.1.0 - \(osVersion)"
    }
}
/// Defines the possible errors
public enum URLSessionAsyncErrors: Error {
    case invalidUrlResponse, missingResponseData
}

/// An extension that provides async support for fetching a URL
///
/// Needed because the Linux version of Swift does not support async URLSession yet.
public extension URLSession {
 
    /// A reimplementation of `URLSession.shared.data(from: url)` required for Linux
    ///
    /// - Parameter url: The URL for which to load data.
    /// - Returns: Data and response.
    ///
    /// - Usage:
    ///
    ///     let (data, response) = try await URLSession.shared.asyncData(from: url)
    func asyncData(from url: URLRequest) async throws -> (Data, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
                    return
                }
                guard let data = data else {
                    continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
                    return
                }
                continuation.resume(returning: (data, response))
            }
            task.resume()
        }
    }
}
