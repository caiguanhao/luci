//
//  NetworkView.swift
//  LuCI
//
//  Created by CGH on 2022/4/4.
//

import Foundation
import SwiftUI

struct NetworkView: View {
    var body: some View {
        NavigationView {
            List {
                IPView()
            }
            .navigationTitle("Network")
        }
        .navigationViewStyle(.stack)
    }
}

struct IPView: View {
    @AppStorage("currentIpAddress") private var current = IPInfo()
    @State var updating: Bool = false

    var data: [[String]] {
        [
            [ "IP Address", current.ipAddress ?? "-" ],
            [ "Location", current.location ?? "-" ],
            [ "Organization", current.orgName ?? "-" ],
            [ "ISP", current.ispName ?? "-" ],
        ]
    }

    var body: some View {
        Section {
            ForEach(data, id: \.self) { line in
                VStack {
                    HStack {
                        Text(line[0])
                        Spacer()
                        Text(line[1]).foregroundColor(.secondary)
                    }
                }
            }
            Button(action: {
                Task {
                    updating = true
                    let resp = try? await IPAddress.IPGeolocation.shared.get()
                    if let info = resp?.toIPInfo() {
                        current = info
                    }
                    updating = false
                }
            }, label: {
                HStack {
                    Text("Update").foregroundColor(updating ? .secondary : .green)
                    if updating {
                        Spacer()
                        ProgressView()
                    } else if current.createdAt != nil {
                        Spacer()
                        Text("Last updated at \(current.createdAtString!)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
            })
        } header: {
            Text("IP Address")
        }
    }
}
