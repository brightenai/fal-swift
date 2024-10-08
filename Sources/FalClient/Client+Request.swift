import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@_implementationOnly import AsyncHTTPClient
@_implementationOnly import NIOCore
@_implementationOnly import NIOFoundationCompat

extension HTTPURLResponse {
    /// Returns `true` if `statusCode` is in range 200...299.
    /// Otherwise `false`.
    var isSuccessful: Bool {
        200 ... 299 ~= statusCode
    }
}

extension Client {
    func sendRequest(to urlString: String, input: Data?, queryParams: [String: Any]? = nil, options: RunOptions) async throws -> Data {
        
//        print("Client send request \(urlString)")
        
        guard var url = URL(string: urlString) else {
            throw FalError.invalidUrl(url: urlString)
        }

//        print("Client send requestB \(urlString)")

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

//        curl --request POST \
//          --url https://queue.fal.run/fal-ai/fast-svd\?fal_webhook\=https://url.to.your.app/api/fal/webhook \
//          --header "Authorization: Key $FAL_KEY" \
//          --header 'Content-Type: application/json' \
//          --data '{
//          "model_name": "stabilityai/stable-diffusion-xl-base-1.0",
//          "prompt": "Photo of a cute dog"
//        }'
//        FAL ERROR1 HTTPClientError.invalidHeaderFieldNames(["application/json", "application/json", "fal.ai/swift-client 0.1.0 - Version 15.0 (Build 24A5298h)", "Key a94ccd57-c4a2-4995-8568-04332edfaaf0:5a1de724fcb3bdb5166c864e37a70340"])

        
//        var request = URLRequest(url: url)
        var request = try HTTPClientRequest(url: url.absoluteString)
        request.method = .POST

        
        //request.method = options.httpMethod.rawValue.uppercased()
        request.headers.add(name:"accept", value: "application/json")
        request.headers.add(name:"content-type", value: "application/json")
        request.headers.add(name:"user-agent", value:userAgent)

        // setup credentials if available
        let credentials = config.credentials.description
        if !credentials.isEmpty {
            
//            print("FAL got credentials \(config.credentials.description)")
            
            request.headers.add(name:  "authorization",value:"Key \(config.credentials.description)")
        }

        // setup the request proxy if available
        if config.requestProxy != nil {
            request.headers.add(name:targetUrl.absoluteString, value: "x-fal-target-url")
        }

        if input != nil, options.httpMethod != .get {
            let bb = ByteBuffer(bytes:input!)
            request.body = HTTPClientRequest.Body.bytes(bb)
        }
        
//        Optional(["Content-Type": "application/json", "Accept": "application/json", "Authorization": "Key a94ccd57-c4a2-4995-8568-04332edfaaf0:5a1de724fcb3bdb5166c864e37a70340", "User-Agent": "fal.ai/swift-client 0.1.0 - Version 15.0 (Build 24A5298h)"])
//
//        request Optional(["User-Agent": "fal.ai/swift-client 0.1.0 - Version 15.0 (Build 24A5298h)", "Authorization": "Key a94ccd57-c4a2-4995-8568-04332edfaaf0:5a1de724fcb3bdb5166c864e37a70340", "Content-Type": "application/json", "Accept": "application/json"])

        
//        print("requestXXX \(request.allHTTPHeaderFields)")
//        print("request \(request.allHTTPHeaderFields)")

        

        request.headers.add(name: "User-Agent", value: "Swift HTTPClient")
//        request.body = .string("some-body")
        let response = try await HTTPClient.shared.execute(request, timeout: .seconds(30))

//        let d:ResponseX = try await withThrowingTaskGroup(of: ResponseX.self) { group in
//            
//            let request2 = request
//            group.addTask
//            {
//                let (data, response) = try await URLSession.shared.asyncData(from: request2)
//                
//                return ResponseX(data: data, response: response)
//            }
//            
//            var finalR = [ResponseX]()
//            for try await result in group {
//                finalR += [result]
//            }
//            
//            return finalR.first!
//
//        }
        
//        let dataVal = try URLConnection.sendSynchronousRequest(request, returningResponse: response)
        
        let body = try await response.body.collect(upTo: 1024 * 1024) // 1 MB
        
        if response.status != .ok
        {
            print("Fal response.status \(response.status)")
            throw FalError.queueTimeout
        }
        
        let data = Data(buffer:body)
//        let data = response.body.
//        let response = d.response
        
//        if let stringX = String(data:data, encoding:.utf8)
//        {
//            print("response from FAL \(stringX)")
//        }
        
        //try checkResponseStatus(for: response, withData: data)
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
            
            print("FalError error \(statusCode) \(message) \(errorPayload)")
            
            throw FalError.httpError(
                status: statusCode,
                message: message,
                payload: errorPayload
            )
        }
    }

    var userAgent: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString //osVersion    String    "Version 15.0 (Build 24A5298h)"
        return "fal.ai/swift-client 0.1.0 - Version 15.0 (Build 24A5298h)"//\(osVersion)"
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
        
        print("asyncData \(url)")

        return try await withCheckedThrowingContinuation { continuation in
            let task = self.dataTask(with: url) { data, response, error in
                
                if let error = error {
                    print("dataTask \(error)")

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

public extension URLRequest {
    
    func cURL() -> String {
        let cURL = "curl -f"
        let method = "-X \(self.httpMethod ?? "GET")"
        let url = url.flatMap { "--url '\($0.absoluteString)'" }
        
        let header = self.allHTTPHeaderFields?
            .map { "-H '\($0): \($1)'" }
            .joined(separator: " ")
        
        let data: String?
        if let httpBody, !httpBody.isEmpty {
            if let bodyString = String(data: httpBody, encoding: .utf8) { // json and plain text
                let escaped = bodyString
                    .replacingOccurrences(of: "'", with: "'\\''")
                data = "--data '\(escaped)'"
            } else { // Binary data
                let hexString = httpBody
                    .map { String(format: "%02X", $0) }
                    .joined()
                data = #"--data "$(echo '\#(hexString)' | xxd -p -r)""#
            }
        } else {
            data = nil
        }
        
        return [cURL, method, url, header, data]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    
}

struct ResponseX
{
    let data:Data
    let response:URLResponse
}


