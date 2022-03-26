//
//  Error.swift
//  LuCI
//
//  Created by CGH on 2022/3/26.
//

import Foundation

enum APIError: LocalizedError {
    case loginFailed(host: String, user: String, pass: String)
    case requestFailed(code: Int, response: String)
}

extension APIError {
    public var errorDescription: String? {
        switch self {
        case .loginFailed(host: let host, user: let user, pass: let pass):
            return "login failed (host: \(host), user: \(user), pass: \(pass))"
        case .requestFailed(code: let code, response: let response):
            let text = response.replacingOccurrences(of: "\n", with: " ")
            let size = 30
            let truncated = (text.count > size) ? text.prefix(size) + "…" : text
            return "responded \(code) with \(truncated)"
        }
    }
}
