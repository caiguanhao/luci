//
//  ContentView.swift
//  LuCI
//
//  Created by CGH on 2022/3/8.
//

import SwiftUI

struct StatusView: View {
    var groups: [LuCI.StatusGroup]

    var body: some View {
        GeometryReader { metrics in
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.statuses) { status in
                            VStack {
                                HStack {
                                    Text(status.key)
                                    Spacer()
                                    Text(status.value)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: metrics.size.width * 0.5, alignment: .trailing)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.5)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(group.name)
                    }
                }
            }
        }
    }
}

struct MainView: View {
    @State var groups: [LuCI.StatusGroup]?
    @AppStorage("host") private var host: String = SettingsView.DEFAULT_HOST
    @AppStorage("user") private var user: String = SettingsView.DEFAULT_USER
    @AppStorage("password") private var password: String = SettingsView.DEFAULT_PASS

    var body: some View {
        NavigationView {
            if (groups != nil) {
                StatusView(groups: groups!)
                    .navigationTitle("Status")
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            let client = LuCI.init(host: host, user: user, pass: password)
            Task {
                try await client.login()
                self.groups = try await client.getStatus()
                try await client.logout()
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            MainView().tabItem {
                Image(systemName: "wifi")
                Text("Status")
            }
            SettingsView().tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
