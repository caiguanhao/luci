//
//  LuCI.swift
//  LuCI
//
//  Created by CGH on 2022/3/19.
//

import Foundation

class LuCI {
    private var api: API

    init(host: String, user: String, pass: String) {
        self.api = API(host: host, user: user, pass: pass)
    }

    func login() async throws {
        try await api.login()
    }

    func logout() async throws {
        try await api.logout()
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
