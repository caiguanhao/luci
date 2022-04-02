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
                List {
                    VStack {
                        Text("(nothing here)").foregroundColor(.secondary)
                    }.listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
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
                    try? await getStatus()
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
    @AppStorage("tabSelection") private var selection: Int = 1

    var body: some View {
        TabView(selection: $selection) {
            MainView().tabItem {
                Image(systemName: "wifi")
                Text("Status")
            }.tag(1)
            SSRView().tabItem {
                Image(systemName: "paperplane")
                Text("ShadowSocksR")
            }.tag(2)
            SettingsView().tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }.tag(3)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
