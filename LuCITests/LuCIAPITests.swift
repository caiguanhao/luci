//
//  LuCITests.swift
//  LuCITests
//
//  Created by CGH on 2022/3/26.
//

import XCTest
@testable import LuCI

class LuCIAPITests: XCTestCase {
    private var api: API!

    override func setUp() async throws {
        let (host, user, pass) = getHUP()
        api = API(host: host, user: user, pass: pass)
        try await api.login()
    }

    override func tearDown() async throws {
        try await api.logout()
    }

    func testGetStatus() async throws {
        let status = try await api.getStatus()
        XCTAssert(status.cpuinfo != "")
        XCTAssert(status.localtime != "")
        XCTAssertGreaterThan(status.uptime, 0)
        XCTAssertGreaterThan(status.memory.total, 0)
        XCTAssertGreaterThan(status.memory.shared, 0)
        XCTAssertGreaterThan(status.memory.free, 0)
        XCTAssertGreaterThan(status.memory.cached, 0)
        XCTAssertGreaterThan(status.memory.available, 0)
        XCTAssertGreaterThan(status.memory.buffered, 0)
    }

    func testShadowSocksR() async throws {
        let settings = try await api.ShadowSocksR_getBasicSettings()
        XCTAssertGreaterThan(settings.count, 0)
        if settings.count > 0 {
            XCTAssertGreaterThan(settings[0].options.count, 0)
        }
    }

    private func getHUP() -> (host: String, user: String, pass: String) {
        // To customize host, user or password, create test.config.json file
        // in project's root directory. For example:
        // {
        //   "pass": "15817878390"
        // }
        if let root = ProcessInfo.processInfo.environment["SRCROOT"] {
            let testConfigFile = NSString.path(withComponents: [root, "test.config.json"])
            if FileManager.default.fileExists(atPath: testConfigFile) {
                struct hup: Decodable { var host: String? ; var user: String? ; var pass: String? }
                do {
                    let config = try String(contentsOfFile: testConfigFile)
                    let obj = try JSONDecoder().decode(hup.self, from: config.data(using: .utf8)!)
                    return (obj.host ?? LuCI.DEFAULT_HOST, obj.user ?? LuCI.DEFAULT_USER, obj.pass ?? LuCI.DEFAULT_PASS)
                } catch {
                    print(error)
                }
            }
        }
        return (LuCI.DEFAULT_HOST, LuCI.DEFAULT_USER, LuCI.DEFAULT_PASS)
    }
}
