//
//  IPInfo.swift
//  LuCI
//
//  Created by CGH on 2022/4/4.
//

import Foundation

struct IPInfo: Codable, RawRepresentable {
    var ipAddress, location, orgName, ispName, latitude, longitude: String?
    var createdAt: Date?
    var createdAtString: String? {
        if createdAt == nil {
            return nil
        }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: createdAt!)
    }

    enum CodingKeys: CodingKey {
        case ipAddress, location, orgName, ispName, latitude, longitude
        case createdAt
    }

    init() {}

    // Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ipAddress = try? container.decode(String.self, forKey: .ipAddress)
        location = try? container.decode(String.self, forKey: .location)
        orgName = try? container.decode(String.self, forKey: .orgName)
        ispName = try? container.decode(String.self, forKey: .ispName)
        latitude = try? container.decode(String.self, forKey: .latitude)
        longitude = try? container.decode(String.self, forKey: .longitude)
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ipAddress, forKey: .ipAddress)
        try container.encode(location, forKey: .location)
        try container.encode(orgName, forKey: .orgName)
        try container.encode(ispName, forKey: .ispName)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(createdAt, forKey: .createdAt)
    }

    // RawRepresentable

    init?(rawValue: String) {
        guard let data = rawValue.data(using: String.Encoding.utf8),
              let result = try? JSONDecoder().decode(IPInfo.self, from: data)
        else {
            return nil
        }
        self = result
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
