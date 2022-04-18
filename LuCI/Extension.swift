//
//  Extension.swift
//  LuCI
//
//  Created by CGH on 2022/4/18.
//

import Foundation

extension Array: RawRepresentable where Self.Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: String.Encoding.utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return result
    }
}
