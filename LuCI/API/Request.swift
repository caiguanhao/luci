//
//  Request.swift
//  LuCI
//
//  Created by CGH on 2022/4/2.
//

import Alamofire
import Foundation

class Request {
    internal var manager: Session = {
        let configuration: URLSessionConfiguration = {
            let configuration = URLSessionConfiguration.default
            configuration.headers = HTTPHeaders.default
            configuration.httpCookieStorage = .none
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.urlCache = nil
            return configuration
        }()
        return Session(configuration: configuration)
    }()

    internal func urlAndHeaders(path: String) -> (String, HTTPHeaders?) {
        return (path, nil)
    }

    internal struct requestOptions {
        var path: String
        var method: HTTPMethod = .get
        var parameters: Parameters? = nil
        var redirect: Bool = true
        var timeout: Double = 5
    }

    private func newRequest(_ opts: requestOptions) -> DataRequest {
        let (url, headers) = self.urlAndHeaders(path: opts.path)
        let req = manager.request(url,
                                  method: opts.method,
                                  parameters: opts.parameters,
                                  headers: headers) {
            $0.timeoutInterval = opts.timeout
        }
        if (opts.redirect == false) {
            req.redirect(using: .doNotFollow)
        }
        return req
    }

    internal func newRequest(_ opts: requestOptions) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.newRequest(opts).response { resp in
                self.handleResponse(resp) { text in
                    continuation.resume(returning: text)
                } fail: { err in
                    continuation.resume(throwing: err)
                }
            }
        }
    }

    internal func newRequest<T: Decodable>(_ opts: requestOptions, type responseType: T.Type) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            self.newRequest(opts).responseDecodable(of: responseType) { resp in
                self.handleResponse(resp) { _ in
                    continuation.resume(returning: resp.value!)
                } fail: { err in
                    continuation.resume(throwing: err)
                }
            }
        }
    }

    private func handleResponse<T>(_ resp: AFDataResponse<T>, ok: (String) -> (), fail: (Error) -> ()) {
        let code = resp.response?.statusCode ?? 0
        let res = resp.data != nil ? (String(data: resp.data!, encoding: .utf8) ?? "(nil)") : "(nil)"
        if (resp.error != nil) {
            fail(APIError.requestFailed(code: code, response: res, afError: resp.error!))
        } else if (code == 200 || code == 204 || code == 301 || code == 302) {
            ok(res)
        } else {
            fail(APIError.requestFailed(code: code, response: res, afError: nil))
        }
    }
}
