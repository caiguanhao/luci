//
//  SettingsView.swift
//  LuCI
//
//  Created by CGH on 2022/3/19.
//

import Foundation
import SwiftUI
import Introspect

struct SettingsView: View {
    @State private var editHost = false
    @AppStorage(LuCI.STORAGE_HOST) private var host: String = LuCI.DEFAULT_HOST
    @AppStorage(LuCI.STORAGE_USER) private var user: String = LuCI.DEFAULT_USER
    @AppStorage(LuCI.STORAGE_PASS) private var pass: String = LuCI.DEFAULT_PASS

    var body: some View {
        NavigationView {
            GeometryReader { metrics in
                List {
                    HStack {
                        Text("Host")
                        Spacer()
                        TextField("Host", text: $host)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                    HStack {
                        Text("User")
                        Spacer()
                        TextField("User", text: $user)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                    HStack {
                        Text("Password")
                        Spacer()
                        SecureField("Password", text: $pass)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
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
