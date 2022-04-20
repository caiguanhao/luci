//
//  ShadowSocksR.swift
//  LuCI
//
//  Created by CGH on 2022/3/27.
//

import Foundation
import Fuzi

extension API {
    struct SSRSettings: Equatable {
        let hiddenFields: [String: String]
        let settings: [SSRSetting]
    }

    struct SSRSetting: Equatable {
        let name: String
        let title: String
        let options: [SSROption]
        let selected: Int
    }

    struct SSROption: Equatable {
        let title: String
        let value: String
    }

    func SSR_getBasicSettings() async throws -> SSRSettings {
        let response = try await self.mkRequest(
            requestOptions(path: "/admin/services/shadowsocksr", redirect: false)
        )
        return try await SSR_parseSettings(response)
    }

    func SSR_parseSettings(_ response: String) async throws -> SSRSettings {
        let doc = try XMLDocument(string: response, encoding: .utf8)
        let form = doc.css("form").first!
        let sections = form.css(".cbi-section-node .cbi-value")
        var hiddenFields = [String: String]()
        for field in form.css("input[type=\"hidden\"]") {
            if let name = field.attr("name"), let value = field.attr("value") {
                hiddenFields[name] = value
            }
        }
        var settings = [SSRSetting]()
        for section in sections {
            let name = section.css(".cbi-input-select").first?.attr("name") ?? ""
            let title = section.css(".cbi-value-title").first?.stringValue ?? ""
            if let input = section.css(".cbi-input-text").first, let choicesText = input.attr("data-choices") {
                let name = input.attr("name") ?? ""
                let choices = try JSONDecoder().decode([[String]].self, from: choicesText.data(using: .utf8)!)
                if choices.count > 1 {
                    var selected = -1
                    var options = [SSROption]()
                    for (index, choice) in choices[0].enumerated() {
                        let option = SSROption(title: choices[1][index], value: choice)
                        options.append(option)
                        if selected == -1 || input.attr("value") == choice {
                            selected = index
                        }
                    }
                    settings.append(SSRSetting(name: name, title: title, options: options, selected: selected))
                    continue
                }
            }
            let items = section.css(".cbi-input-select option")
            if items.count > 0 {
                var selected = -1
                var options = [SSROption]()
                for (index, item) in items.enumerated() {
                    let value = item.attr("value") ?? ""
                    let option = SSROption(title: item.stringValue, value: value)
                    if selected == -1 || item.attr("selected") != nil {
                        selected = index
                    }
                    options.append(option)
                }
                settings.append(SSRSetting(name: name, title: title, options: options, selected: selected))
                continue
            }
        }
        return SSRSettings(hiddenFields: hiddenFields, settings: settings)
    }

    func SSR_updateSettings(_ group: SSRSettings) async throws -> SSRSettings {
        var data = [String: String]()
        for (key, value) in group.hiddenFields {
            data[key] = value
        }
        for setting in group.settings {
            if setting.selected < 0 || setting.selected >= setting.options.count {
                continue
            }
            let value = setting.options[setting.selected].value
            data[setting.name] = value
        }
        let response = try await self.mkRequest(
            requestOptions(path: "/admin/services/shadowsocksr",
                           method: .post, parameters: data, redirect: false)
        )
        return try await SSR_parseSettings(response)
    }

    func SSR_restart(token: String) async throws -> Bool {
        let data = [ "token": token ]
        let response = try await self.mkRequest(
            requestOptions(path: "/servicectl/restart/shadowsocksr",
                           method: .post, parameters: data)
        )
        return response == "OK"
    }

    struct Server: Codable {
        let id: String
        let type: String
        let name: String
        let domain: String
        let port: String
        let transport: String
        let wsPath: String
        let tls: String
        var description: String {
            return String(describing: self)
        }
    }

    func SSR_getServerNodes() async throws -> [Server] {
        let response = try await self.mkRequest(
            requestOptions(path: "/admin/services/shadowsocksr/servers", redirect: false)
        )
        let doc = try XMLDocument(string: response, encoding: .utf8)
        let rows = doc.css(".cbi-section-table-row")
        var servers = [Server]()
        for row in rows {
            let idStr = row.attr("id")
            if idStr == nil {
                continue
            }
            let inputs = row.css("input")
            var type: String?
            var name: String?
            for input in inputs {
                let id = input.attr("id")
                if id == nil {
                    continue
                }
                if id!.hasSuffix(".type") {
                    type = input.attr("value")
                }
                if id!.hasSuffix(".alias") {
                    name = input.attr("value")
                }
            }
            if name == nil || type == nil {
                continue
            }
            let id = idStr!.replacingOccurrences(of: "cbi-shadowsocksr-", with: "")
            let domain = row.css(".pingtime").first?.attr("hint") ?? ""
            let port = row.css(".socket-connected").first?.attr("hint") ?? ""
            let transport = row.css(".transport").first?.attr("hint") ?? ""
            let wsPath = row.css(".wsPath").first?.attr("hint") ?? ""
            let tls = row.css(".tls").first?.attr("hint") ?? ""
            servers.append(Server(id: id, type: type!, name: name!,
                                  domain: domain, port: port,
                                  transport: transport, wsPath: wsPath, tls: tls))
        }
        return servers
    }

    struct PingResult: Codable {
        let ping: Int
        let socket: Bool
    }

    func SSR_pingServerNode(_ server: Server) async throws -> PingResult {
        var components = URLComponents()
        components.path = "/admin/services/shadowsocksr/ping"
        components.queryItems = [
            URLQueryItem(name: "domain", value: server.domain),
            URLQueryItem(name: "port", value: server.port),
            URLQueryItem(name: "transport", value: server.transport),
            URLQueryItem(name: "wsPath", value: server.wsPath),
            URLQueryItem(name: "tls", value: server.tls)
        ]
        let url = components.url?.absoluteString
        return try await self.mkRequest(requestOptions(path: url!, timeout: 10), type: PingResult.self)
    }

    struct RunningResult: Codable {
        let running: Bool
    }

    func SSR_checkIfRunning() async throws -> Bool {
        let result = try await self.mkRequest(requestOptions(path: "/admin/services/shadowsocksr/run"), type: RunningResult.self)
        return result.running
    }
}
