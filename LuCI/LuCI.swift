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

    static let STORAGE_ACCOUNTS = "accounts"
    static let STORAGE_CURRENT_ACCOUNT_ID = "currentAccountId"

    static func HUP() -> (host: String, user: String, pass: String) {
        if let data = UserDefaults.standard.string(forKey: LuCI.STORAGE_ACCOUNTS)?.data(using: .utf8) {
            let accounts = try? JSONDecoder().decode([Account].self, from: data)
            let id = UserDefaults.standard.string(forKey: LuCI.STORAGE_CURRENT_ACCOUNT_ID) ?? ""
            if let account = accounts?.first(where: { $0.id.uuidString == id }) {
                return (account.host, account.user, account.pass)
            }
        }
        return (LuCI.DEFAULT_HOST, LuCI.DEFAULT_USER, LuCI.DEFAULT_PASS)
    }

    struct Account: Identifiable, Codable, Equatable {
        var id = UUID()
        let name: String
        let host: String
        let user: String
        let pass: String
        var display: String {
            if name.count > 0 {
                return name
            }
            let masked = String(repeating: "•", count: max(0, pass.count-3)) + pass.suffix(3)
            return "\(user):\(masked)@\(host)"
        }
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

    struct StatusGroup: Identifiable, Codable {
        var id = UUID()
        let name: String
        let statuses: [Status]
        var emptyMessage: String? = nil
        var isEmpty: Bool {
            return statuses.count == 0
        }
    }

    struct Status: Identifiable, Codable {
        var id = UUID()
        let key: String
        let value: String
    }

    func getStatus() async throws -> [StatusGroup] {
        try await update()
        let staticStatus = try await api.getStaticStatus()
        let s = try await api.getStatus()
        var groups = [StatusGroup]()
        groups.append(StatusGroup(name: "System", statuses: [
            Status(key: "Hostname", value: staticStatus.hostname),
            Status(key: "Model", value: staticStatus.model),
            Status(key: "Architecture", value: s.cpuinfo),
            Status(key: "Firmware Version", value: staticStatus.firmwareVersion),
            Status(key: "Kernel Version", value: staticStatus.kernelVersion),
            Status(key: "Local Time", value: s.localtime),
            Status(key: "Uptime", value: toDuration(s.uptime)),
            Status(key: "Load Average", value: toLoadAvg(s.loadavg)),
            Status(key: "CPU usage (%)", value: s.cpuusage),
        ]))
        let memcached = Int(s.memcached.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let memory = "\((s.memory.free + s.memory.buffered) / 1048576 + (memcached / 1024)) MB / \(s.memory.total / 1048576) MB"
        groups.append(StatusGroup(name: "Memory", statuses: [
            Status(key: "Total Available", value: memory),
            Status(key: "Buffered", value: "\(s.memory.buffered / 1048576) MB / \(s.memory.total / 1048576) MB"),
        ]))
        if let leases = s.leases {
            var items = [Status]()
            for lease in leases {
                let key = "\(lease.ipaddr ?? "?")\n\(lease.hostname?.value ?? "?")"
                let value = "\(lease.macaddr ?? "?")\n\(toDuration(lease.expires ?? 0))"
                items.append(Status(key: key, value: value))
            }
            groups.append(StatusGroup(name: "DHCP Leases", statuses: items, emptyMessage: "There are no active leases."))
        }
        if let wifis = s.wifinets {
            for wifi in wifis {
                var items: [Status] = [
                    Status(key: "Name", value: wifi.name ?? "?"),
                ]
                if let networks = wifi.networks {
                    for network in networks {
                        items.append(Status(key: "SSID", value: network.ssid ?? "?"))
                        items.append(Status(key: "Mode", value: network.mode ?? "?"))
                        items.append(Status(key: "Quality", value: String(format: "%d%%", network.quality ?? 0)))
                        items.append(Status(key: "Signal", value: String(format: "%d dBm", network.signal ?? 0)))
                        items.append(Status(key: "Noise", value: String(format: "%d dBm", network.noise ?? 0)))
                        let channel = String(format: "%d (%@ GHz)", network.channel ?? 0, network.frequency ?? "?")
                        items.append(Status(key: "Channel", value: channel))
                        items.append(Status(key: "Bitrate", value: String(format: "%@ Mbit/s", network.bitrate ?? "?")))
                        let isAssoc = network.bssid != nil && network.bssid != "00:00:00:00:00:00" &&
                        network.channel != nil && network.channel! > 0 &&
                        network.disabled == false
                        if isAssoc {
                            items.append(Status(key: "BSSID", value: network.bssid ?? "?"))
                            items.append(Status(key: "Encryption", value: network.encryption ?? "?"))
                        } else {
                            items.append(Status(key: "Status", value: "Wireless is disabled or not associated"))
                        }
                    }
                    groups.append(StatusGroup(name: "Wireless", statuses: items))
                }
            }
        }
        return groups
    }

    final class ShadowSocksRGroups: ObservableObject, Codable, RawRepresentable {
        @Published var groups = [ShadowSocksRGroup]()
        @Published var isOnOptionsPage = false

        enum CodingKeys: CodingKey {
            case groups
            case isOnOptionsPage
        }

        func setSelected(group: ShadowSocksRGroup, settingIndex: Int, index: Int) {
            if let idx = groups.firstIndex(where: { $0.id == group.id }) {
                self.groups[idx].settings[settingIndex].selectedIndex = index
            }
        }

        init() {}

        // Codable

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            groups = try container.decode([ShadowSocksRGroup].self, forKey: .groups)
            isOnOptionsPage = try container.decode(Bool.self, forKey: .isOnOptionsPage)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(groups, forKey: .groups)
            try container.encode(isOnOptionsPage, forKey: .isOnOptionsPage)
        }

        // RawRepresentable

        init?(rawValue: String) {
            guard let data = rawValue.data(using: String.Encoding.utf8),
                  let result = try? JSONDecoder().decode(LuCI.ShadowSocksRGroups.self, from: data)
            else {
                return nil
            }
            self.groups = result.groups
        }

        var rawValue: String {
            guard let data = try? JSONEncoder().encode(self),
                let result = String(data: data, encoding: .utf8)
            else {
                return ""
            }
            return result
        }
    }

    struct ShadowSocksRGroup: Identifiable, Codable {
        var id = UUID()
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

    struct ShadowSocksRSetting: Identifiable, Codable {
        var id = UUID()
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

    struct ShadowSocksROption: Identifiable, Codable {
        var id = UUID()
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
        let groups = ShadowSocksRGroups()
        groups.groups = [
            ShadowSocksRGroup(title: "BASIC", hiddenFields: ssrSettings.hiddenFields, settings: settings)
        ]
        return groups
    }

    func updateSSRSettings(_ group: ShadowSocksRGroup) async throws -> ShadowSocksRGroups {
        try await update()
        var ss = [API.SSRSetting]()
        for setting in group.settings {
            ss.append(setting.asSetting())
        }
        let input = API.SSRSettings(hiddenFields: group.hiddenFields, settings: ss)
        let ssrSettings = try await api.SSR_updateSettings(input)
        _ = try await api.SSR_restart(token: ssrSettings.hiddenFields["token"] ?? "")
        var i = 0
        while i < 10 {
            let running = try await checkRunning()
            if i > 3 && running == true {
                break
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            i += 1
        }
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

    func checkRunning() async throws -> Bool {
        return try await api.SSR_checkIfRunning()
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
