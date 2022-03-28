//
//  ShadowSocksR.swift
//  LuCI
//
//  Created by CGH on 2022/3/27.
//

import Foundation
import Fuzi

extension API {
    struct Setting {
        let name: String
        let title: String
        var options: [Option]
        let selected: Int
    }

    struct Option {
        let title: String
        let value: String
    }

    func ShadowSocksR_getBasicSettings() async throws -> [Setting] {
        let response = try await self.getRequest("/admin/services/shadowsocksr", redirect: false)
        let doc = try XMLDocument(string: response, encoding: .utf8)
        let sections = doc.css(".cbi-section-node .cbi-value")
        var settings = [Setting]()
        for section in sections {
            let name = section.css(".cbi-input-select").first?.attr("name") ?? ""
            let title = section.css(".cbi-value-title").first?.stringValue ?? ""
            if let input = section.css(".cbi-input-text").first, let choicesText = input.attr("data-choices") {
                let choices = try JSONDecoder().decode([[String]].self, from: choicesText.data(using: .utf8)!)
                if choices.count > 1 {
                    var selected = -1
                    var options = [Option]()
                    for (index, choice) in choices[0].enumerated() {
                        let option = Option(title: choices[1][index], value: choice)
                        options.append(option)
                        if selected == -1 || input.attr("value") == choice {
                            selected = index
                        }
                    }
                    settings.append(Setting(name: name, title: title, options: options, selected: selected))
                    continue
                }
            }
            let items = section.css(".cbi-input-select option")
            if items.count > 0 {
                var selected = -1
                var options = [Option]()
                for (index, item) in items.enumerated() {
                    let value = item.attr("value") ?? ""
                    let option = Option(title: item.stringValue, value: value)
                    if selected == -1 || item.attr("selected") != nil {
                        selected = index
                    }
                    options.append(option)
                }
                settings.append(Setting(name: name, title: title, options: options, selected: selected))
                continue
            }
        }
        return settings
    }
}
