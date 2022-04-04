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

    internal func getRequest<T: Decodable>(_ path: String, type responseType: T.Type, timeout: Double = 5) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            self.newRequest(path, timeout: timeout).responseDecodable(of: responseType) { resp in
                self.handleResponse(resp) { _ in
                    continuation.resume(returning: resp.value!)
                } fail: { err in
                    continuation.resume(throwing: err)
                }
            }
        }
    }

    internal func urlAndHeaders(path: String) -> (String, HTTPHeaders?) {
        return (path, nil)
    }

    internal func newRequest(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        redirect: Bool = true,
        timeout: Double = 5
    ) -> DataRequest {
        let (url, headers) = self.urlAndHeaders(path: path)
        let req = manager.request(url, method: method, parameters: parameters, headers: headers) {
            $0.timeoutInterval = timeout
        }
        if (redirect == false) {
            req.redirect(using: .doNotFollow)
        }
        return req
    }

    internal func handleResponse<T>(_ resp: AFDataResponse<T>, ok: (String) -> (), fail: (Error) -> ()) {
        let code = resp.response?.statusCode ?? 0
        let res = resp.data != nil ? (String(data: resp.data!, encoding: .utf8) ?? "(nil)") : "(nil)"
        if (resp.error != nil) {
            fail(resp.error!)
        } else if (code == 200 || code == 204 || code == 301 || code == 302) {
            ok(res)
        } else {
            fail(APIError.requestFailed(code: code, response: res))
        }
    }
}
