//
//  LuCI.swift
//  LuCI
//
//  Created by CGH on 2022/3/19.
//

import Foundation
import os.log

class LuCI {
    static let DEFAULT_HOST = "192.168.2.1"
    static let DEFAULT_USER = "root"
    static let DEFAULT_PASS = "password"

    static let STORAGE_HOST = "host"
    static let STORAGE_USER = "user"
    static let STORAGE_PASS = "pass"

    static func HUP() -> (host: String, user: String, pass: String) {
        let host: String = UserDefaults.standard.string(forKey: LuCI.STORAGE_HOST) ?? LuCI.DEFAULT_HOST
        let user: String = UserDefaults.standard.string(forKey: LuCI.STORAGE_USER) ?? LuCI.DEFAULT_USER
        let pass: String = UserDefaults.standard.string(forKey: LuCI.STORAGE_PASS) ?? LuCI.DEFAULT_PASS
        return (host, user, pass)
    }

    static var shared = LuCI()

    private var api: API

    init() {
        let (host, user, pass) = LuCI.HUP()
        self.api = API(host: host, user: user, pass: pass)
    }

    func update() async throws {
        let (host, user, pass) = LuCI.HUP()
        try await api.update(host: host, user: user, pass: pass)
    }

    func cancelAll() {
        api.cancelAll()
    }

    struct StatusGroup: Identifiable {
        let id = UUID()
        let name: String
        let statuses: [Status]
    }

    struct Status: Identifiable {
        let id = UUID()
        let key: String
        let value: String
    }

    func getStatus() async throws -> [StatusGroup] {
        try await update()
        let staticStatus = try await api.getStaticStatus()
        let s = try await api.getStatus()
        return [
            StatusGroup(name: "System", statuses: [
                Status(key: "Hostname", value: staticStatus.hostname),
                Status(key: "Model", value: staticStatus.model),
                Status(key: "Architecture", value: s.cpuinfo),
                Status(key: "Firmware Version", value: staticStatus.firmwareVersion),
                Status(key: "Kernel Version", value: staticStatus.kernelVersion),
                Status(key: "Local Time", value: s.localtime),
                Status(key: "Uptime", value: toDuration(s.uptime)),
                Status(key: "Load Average", value: toLoadAvg(s.loadavg)),
                Status(key: "CPU usage (%)", value: s.cpuusage),
            ]),
        ]
    }

    class ShadowSocksRGroups: ObservableObject {
        @Published var groups = [ShadowSocksRGroup]()

        init(groups: [ShadowSocksRGroup]) {
            self.groups = groups
        }

        func update(_ groups: ShadowSocksRGroups) {
            self.groups = groups.groups
        }
    }

    struct ShadowSocksRGroup: Identifiable {
        let id = UUID()
        let title: String
        var hiddenFields: [String: String]
        var settings: [ShadowSocksRSetting]
        var hasChanaged: Bool {
            for setting in settings {
                if setting.originalSelectedIndex != setting.selectedIndex {
                    return true
                }
            }
            return false
        }
    }

    struct ShadowSocksRSetting: Identifiable {
        let id = UUID()
        let name: String
        let title: String
        let options: [ShadowSocksROption]
        var originalSelectedIndex: Int
        var selectedIndex: Int
        var value: String {
            return selectedIndex > -1 && selectedIndex < options.count ? options[selectedIndex].value : "null"
        }
        var valueText: String {
            return selectedIndex > -1 && selectedIndex < options.count ? options[selectedIndex].title : "-"
        }
        func asSetting() -> API.SSRSetting {
            var opts = [API.SSROption]()
            for option in options {
                opts.append(option.asOption())
            }
            return API.SSRSetting(name: name, title: title, options: opts, selected: selectedIndex)
        }
    }

    struct ShadowSocksROption: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        func asOption() -> API.SSROption {
            return API.SSROption(title: title, value: value)
        }
    }

    func getShadowSocks() async throws -> ShadowSocksRGroups {
        try await update()
        let ssrSettings = try await api.SSR_getBasicSettings()
        return toShadowSocksRGroups(ssrSettings)
    }

    func toShadowSocksRGroups(_ ssrSettings: API.SSRSettings) -> ShadowSocksRGroups {
        var settings = [ShadowSocksRSetting]()
        for item in ssrSettings.settings {
            var options = [ShadowSocksROption]()
            for option in item.options {
                options.append(ShadowSocksROption(title: option.title, value: option.value))
            }
            settings.append(ShadowSocksRSetting(name: item.name, title: item.title,
                                                options: options,
                                                originalSelectedIndex: item.selected,
                                                selectedIndex: item.selected))
        }
        return ShadowSocksRGroups(groups: [
            ShadowSocksRGroup(title: "BASIC", hiddenFields: ssrSettings.hiddenFields, settings: settings)
        ])
    }

    func updateSSRSettings(_ group: ShadowSocksRGroup) async throws -> ShadowSocksRGroups {
        try await update()
        var ss = [API.SSRSetting]()
        for setting in group.settings {
            ss.append(setting.asSetting())
        }
        let input = API.SSRSettings(hiddenFields: group.hiddenFields, settings: ss)
        let ssrSettings = try await api.SSR_updateSettings(input)
        return toShadowSocksRGroups(ssrSettings)
    }

    class ShadowSocksRServers: ObservableObject, CustomStringConvertible {
        @Published var servers = [ShadowSocksRServer]()

        var count: Int {
            return self.servers.count
        }

        var description: String {
            return servers.description
        }

        func append(_ server: ShadowSocksRServer) {
            self.servers.append(server)
        }

        func removeAll() {
            self.servers.removeAll()
        }

        func update(_ server: ShadowSocksRServer) {
            for i in servers.indices {
                if servers[i] === server {
                    self.servers.remove(at: i)
                    break
                }
            }
            self.servers.append(server)
        }
    }

    class ShadowSocksRServer: CustomStringConvertible {
        let server: API.Server
        var testing: Bool = false
        var socketConnected: Bool?
        var pingLatency: Int?

        init(_ server: API.Server) {
            self.server = server
        }

        var description: String {
            return server.description +
            "(socketConnected: \(String(describing: socketConnected)), " +
            "pingLatency: \(String(describing: pingLatency)))"
        }
    }

    func getShadowSocksRServerNodes() async throws -> [ShadowSocksRServer] {
        try await update()
        let servers = try await api.SSR_getServerNodes()
        var nodes = [ShadowSocksRServer]()
        for s in servers {
            nodes.append(ShadowSocksRServer(s))
        }
        return nodes
    }

    func pingServer(_ server: ShadowSocksRServer) async throws -> (Bool, Int) {
        let srv = server.server
        os_log("PING %@ PORT %@ TYPE %@", srv.domain, srv.port, srv.type)
        let result = try await api.SSR_pingServerNode(srv)
        return (result.socket, result.ping)
    }

    private func toDuration(_ duration: Int) -> String {
        let fmt = DateComponentsFormatter()
        fmt.unitsStyle = .abbreviated
        fmt.zeroFormattingBehavior = .dropAll
        fmt.allowedUnits = [ .day, .hour, .minute, .second ]
        return fmt.string(from: TimeInterval(duration))!
    }

    private func toLoadAvg(_ loadAvg: [Int]) -> String {
        return String(format: "%.02f, %.02f, %.02f",
                      Float(loadAvg[0]) / 65535.0,
                      Float(loadAvg[1]) / 65535.0,
                      Float(loadAvg[2]) / 65535.0)
    }
}
