//
//  SettingsView.swift
//  LuCI
//
//  Created by CGH on 2022/3/19.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    static let DEFAULT_HOST = "192.168.2.1"
    static let DEFAULT_USER = "root"
    static let DEFAULT_PASS = "password"

    @State private var editHost = false
    @AppStorage("host") private var host: String = DEFAULT_HOST
    @AppStorage("user") private var user: String = DEFAULT_USER
    @AppStorage("password") private var password: String = DEFAULT_PASS

    var body: some View {
        NavigationView {
            GeometryReader { metrics in
                List {
                    HStack {
                        Text("Host")
                        Spacer()
                        TextField("Host", text: $host)
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                    HStack {
                        Text("User")
                        Spacer()
                        TextField("User", text: $user)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                    HStack {
                        Text("Password")
                        Spacer()
                        SecureField("Password", text: $password)
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                }.navigationTitle("Settings")
            }
        }.navigationViewStyle(.stack)
    }
}

func BetterText(_ content: String, width: CGFloat) -> some View {
    return Text(content)
        .multilineTextAlignment(.trailing)
        .frame(width: width, alignment: .trailing)
        .lineLimit(2)
        .minimumScaleFactor(0.5)
        .foregroundStyle(.secondary)
}
