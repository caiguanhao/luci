//
//  API.swift
//  LuCI
//
//  Created by CGH on 2022/3/9.
//

import Alamofire
import Foundation
import Fuzi

class API: Request {
    private var host: String
    private var user: String
    private var pass: String

    private var auth: String?
    private var staticStatus: StaticStatus?

    init(host: String, user: String, pass: String) {
        self.host = host
        self.user = user
        self.pass = pass
    }

    func cancelAll() {
        self.manager.cancelAllRequests()
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

    override func urlAndHeaders(path: String) -> (String, HTTPHeaders?) {
        return ("http://\(self.host)/cgi-bin/luci\(path)", HTTPHeaders([ "Cookie": "sysauth=\(self.auth ?? "")" ]))
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
        _ = try await mkRequest("/admin/logout", redirect: false)
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
        let response = try await mkRequest("/", redirect: false)
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

    internal func mkRequest(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        redirect: Bool = true,
        timeout: Double = 5
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.newRequest(
                path, method: method, parameters: parameters,
                redirect: redirect, timeout: timeout
            ).response { resp in
                self.handleResponse(resp) { text in
                    continuation.resume(returning: text)
                } fail: { err in
                    continuation.resume(throwing: err)
                }
            }
        }
    }
}
