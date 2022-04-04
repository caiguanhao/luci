//
//  IPAddressTests.swift
//  LuCITests
//
//  Created by CGH on 2022/4/2.
//

import XCTest
@testable import LuCI

class IPAddressTests: XCTestCase {
    func testIPGeolocation() async throws {
        let resp = try await IPAddress.IPGeolocation.shared.get()
        let info = resp.toIPInfo()
        XCTAssertNotNil(info.ipAddress)
        XCTAssertNotNil(info.location)
        XCTAssertNotNil(info.orgName)
        XCTAssertNotNil(info.ispName)
        XCTAssertNotNil(info.latitude)
        XCTAssertNotNil(info.longitude)
    }
}
