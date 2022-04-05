//
//  IPAddress.swift
//  LuCI
//
//  Created by CGH on 2022/4/2.
//

import Foundation

class IPAddress {
    // https://ipgeolocation.io/
    // FREE: 1K daily or 30K monthly
    class IPGeolocation: Request {
        static var shared = IPGeolocation()

        func get() async throws -> ipgeolocationResponse {
            let key = UserDefaults.standard.string(forKey: "ipgeolocationApiKey") ?? ""
            let url = "https://api.ipgeolocation.io/ipgeo?apiKey=\(key)"
            do {
                return try await getRequest(url, type: ipgeolocationResponse.self, timeout: 5)
            } catch APIError.requestFailed(let code, var response) {
                if response.count > 0 {
                    let resp = try JSONDecoder().decode([String: String].self, from: response.data(using: .utf8)!)
                    response = resp["message"] ?? response
                }
                throw APIError.requestFailed(code: code, response: response)
            } catch let error {
                throw error
            }
        }

        struct ipgeolocationResponse: Codable {
            func toIPInfo() -> IPInfo {
                var info = IPInfo()
                info.ipAddress = ip
                let n1 = city ?? ""
                let n2 = countryName ?? ""
                if n1.isEmpty && n2.isEmpty {
                    info.location = "?"
                } else if n2.isEmpty {
                    info.location = "\(n1)"
                } else if n1.isEmpty {
                    info.location = "\(n2)"
                } else {
                    info.location = "\(n1), \(n2)"
                }
                info.orgName = organization
                info.ispName = isp
                info.latitude = latitude
                info.longitude = longitude
                info.createdAt = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded())
                return info
            }

            let ip: String?
            let continentCode: String?
            let continentName: String?
            let countryCode2: String?
            let countryCode3: String?
            let countryName: String?
            let countryCapital: String?
            let stateProv: String?
            let district: String?
            let city: String?
            let zipcode: String?
            let latitude: String?
            let longitude: String?
            let isEu: Bool?
            let callingCode: String?
            let countryTLD: String?
            let languages: String?
            let countryFlag: String?
            let geonameID: String?
            let isp: String?
            let connectionType: String?
            let organization: String?
            let currency: ipgeolocationCurrency?
            let timeZone: ipgeolocationTimeZone?

            enum CodingKeys: String, CodingKey {
                case ip = "ip"
                case continentCode = "continent_code"
                case continentName = "continent_name"
                case countryCode2 = "country_code2"
                case countryCode3 = "country_code3"
                case countryName = "country_name"
                case countryCapital = "country_capital"
                case stateProv = "state_prov"
                case district = "district"
                case city = "city"
                case zipcode = "zipcode"
                case latitude = "latitude"
                case longitude = "longitude"
                case isEu = "is_eu"
                case callingCode = "calling_code"
                case countryTLD = "country_tld"
                case languages = "languages"
                case countryFlag = "country_flag"
                case geonameID = "geoname_id"
                case isp = "isp"
                case connectionType = "connection_type"
                case organization = "organization"
                case currency = "currency"
                case timeZone = "time_zone"
            }
        }

        struct ipgeolocationCurrency: Codable {
            let code: String?
            let name: String?
            let symbol: String?

            enum CodingKeys: String, CodingKey {
                case code = "code"
                case name = "name"
                case symbol = "symbol"
            }
        }

        struct ipgeolocationTimeZone: Codable {
            let name: String?
            let offset: Int?
            let currentTime: String?
            let currentTimeUnix: Double?
            let isDst: Bool?
            let dstSavings: Int?

            enum CodingKeys: String, CodingKey {
                case name = "name"
                case offset = "offset"
                case currentTime = "current_time"
                case currentTimeUnix = "current_time_unix"
                case isDst = "is_dst"
                case dstSavings = "dst_savings"
            }
        }
    }
}
