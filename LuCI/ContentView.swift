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

    func getStatus() async throws {
        do {
            self.groups = try await LuCI.shared.getStatus()
        } catch {
            self.groups = nil
        }
    }

    var status: some View {
        Group {
            if groups == nil {
                Text("(nothing here)").foregroundColor(.secondary)
            } else {
                StatusView(groups: groups!)
            }
        }
    }

    var body: some View {
        NavigationView {
            status
                .navigationTitle("Status")
                .refreshable {
                    Task {
                        try await getStatus()
                    }
                }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
                try await getStatus()
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
