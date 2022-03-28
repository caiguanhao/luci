//
//  LuCI.swift
//  LuCI
//
//  Created by CGH on 2022/3/19.
//

import Foundation

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

    struct ShadowSocksRGroup: Identifiable {
        let id = UUID()
        let title: String
        let settings: [ShadowSocksRSetting]
    }

    struct ShadowSocksRSetting: Identifiable {
        let id = UUID()
        let title: String
        let value: String
    }

    func getShadowSocks() async throws -> [ShadowSocksRGroup] {
        try await update()
        let items = try await api.ShadowSocksR_getBasicSettings()
        var settings = [ShadowSocksRSetting]()
        for item in items {
            let value = item.selected > -1 ? item.options[item.selected].title : "-"
            settings.append(ShadowSocksRSetting(title: item.title, value: value))
        }
        return [
            ShadowSocksRGroup(title: "BASIC", settings: settings)
        ]
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
