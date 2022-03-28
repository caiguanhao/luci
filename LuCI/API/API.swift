//
//  API.swift
//  LuCI
//
//  Created by CGH on 2022/3/9.
//

import Alamofire
import Foundation
import Fuzi

class API {
    private var host: String
    private var user: String
    private var pass: String

    private var auth: String?
    private var staticStatus: StaticStatus?

    private var manager: Session = {
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

    init(host: String, user: String, pass: String) {
        self.host = host
        self.user = user
        self.pass = pass
    }

    func update(host: String, user: String, pass: String) async throws {
        if self.host != host || self.user != user || self.pass != pass {
            self.host = host
            self.user = user
            self.pass = pass
            self.auth = nil
            self.staticStatus = nil
        }
        if self.auth == nil {
            try await login()
        }
    }

    func login() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let data: [String: String] = [
                "luci_username": self.user,
                "luci_password": self.pass,
            ]
            let url = "http://\(self.host)/cgi-bin/luci/"
            manager.request(url, method: .post, parameters: data) { $0.timeoutInterval = 3 }
            .redirect(using: .doNotFollow)
            .response { resp in
                if resp.error != nil {
                    continuation.resume(throwing: resp.error!)
                    return
                }
                let fields = resp.response?.allHeaderFields as? [String: String]
                let url = resp.response?.url
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: fields!, for: url!)
                for cookie in cookies {
                    if cookie.name == "sysauth" {
                        self.auth = cookie.value
                        continuation.resume()
                        return
                    }
                }
                continuation.resume(throwing: APIError.loginFailed(host: self.host, user: self.user, pass: self.pass))
            }
        }
    }

    func logout() async throws {
        _ = try await getRequest("/admin/logout", redirect: false)
    }

    struct StaticStatus {
        let hostname: String
        let model: String
        let firmwareVersion: String
        let kernelVersion: String
    }

    func getStaticStatus() async throws -> StaticStatus {
        if (self.staticStatus != nil) {
            return self.staticStatus!
        }
        let response = try await getRequest("/", redirect: false)
        let doc = try XMLDocument(string: response, encoding: .utf8)
        let fieldsets = doc.css("fieldset")
        let tds = fieldsets[0].css("td")
        return StaticStatus(
            hostname: removeSpaces(tds[1].stringValue),
            model: removeSpaces(tds[3].stringValue),
            firmwareVersion: removeSpaces(tds[7].stringValue),
            kernelVersion: removeSpaces(tds[9].stringValue)
        )
    }

    private func removeSpaces(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "[\\s\\n]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getStatus() async throws -> Status {
        if (self.staticStatus == nil) {
            self.staticStatus = try await getStaticStatus()
        }
        return try await getRequest("/?status=1", type: Status.self)
    }

    struct Status: Codable {
        let memcached: String
        let swap: Swap
        let ethinfo: String
        let userinfo: String
        let conncount, connmax: Int
        let memory: Memory
        let uptime: Int
        let cpuinfo: String
        let wan: WAN
        let localtime, cpuusage: String
        let loadavg: [Int]
    }

    struct Memory: Codable {
        let total, shared, free, cached: Int
        let available, buffered: Int
    }

    struct Swap: Codable {
        let free, total: Int
    }

    struct WAN: Codable {
        let proto, ipaddr, link, netmask: String
        let gwaddr: String
        let expires, uptime: Int
        let ifname: String
        let dns: [String]
    }

    internal func getRequest(_ path: String, redirect: Bool = true) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.newRequest(path, redirect: redirect).response { resp in
                self.handleResponse(resp) { text in
                    continuation.resume(returning: text)
                } fail: { err in
                    continuation.resume(throwing: err)
                }
            }
        }
    }

    private func getRequest<T: Decodable>(_ path: String, type responseType: T.Type) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            self.newRequest(path).responseDecodable(of: responseType) { resp in
                self.handleResponse(resp) { _ in
                    continuation.resume(returning: resp.value!)
                } fail: { err in
                    continuation.resume(throwing: err)
                }
            }
        }
    }

    private func newRequest(_ path: String, redirect: Bool = true) -> DataRequest {
        let url = "http://\(self.host)/cgi-bin/luci\(path)"
        let headers: [String: String] = [
            "Cookie": "sysauth=\(self.auth ?? "")",
        ]
        let req = manager.request(url, method: .get, headers: HTTPHeaders(headers)) {
            $0.timeoutInterval = 3
        }
        if (redirect == false) {
            req.redirect(using: .doNotFollow)
        }
        return req
    }

    private func handleResponse<T>(_ resp: AFDataResponse<T>, ok: (String) -> (), fail: (Error) -> ()) {
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
