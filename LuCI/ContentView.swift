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

struct ShadowSocksROptionsView: View {
    @EnvironmentObject var settings: LuCI.ShadowSocksRGroups
    @Environment(\.presentationMode) var presentationMode

    let groupIdx: Int
    let settingIdx: Int

    var setting: LuCI.ShadowSocksRSetting {
        return settings.groups[groupIdx].settings[settingIdx]
    }

    var body: some View {
        ForEach(setting.options.indices, id: \.self) { index in
            VStack {
                Button(action: {
                    settings.groups[groupIdx].settings[settingIdx].selectedIndex = index
                    self.presentationMode.wrappedValue.dismiss()
                }, label: {
                    HStack {
                        Text(setting.options[index].title)
                            .foregroundColor(index == setting.selectedIndex ? .accentColor : .primary)
                    }
                })
            }
        }
    }
}

struct ShadowSocksRSettingsView: View {
    @EnvironmentObject var settings: LuCI.ShadowSocksRGroups

    var body: some View {
        GeometryReader { metrics in
            List {
                ForEach(settings.groups.indices) { groupIdx in
                    let group = settings.groups[groupIdx]
                    Section {
                        ForEach(group.settings.indices) { settingIdx in
                            let setting = group.settings[settingIdx]
                            VStack {
                                NavigationLink(destination: {
                                    List {
                                        ShadowSocksROptionsView(groupIdx: groupIdx,
                                                                settingIdx: settingIdx)
                                            .environmentObject(settings)
                                    }.navigationTitle(setting.title)
                                }, label: {
                                    HStack {
                                        Text(setting.title)
                                        Spacer()
                                        Text(setting.valueText)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: metrics.size.width * 0.4, alignment: .trailing)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.5)
                                            .foregroundStyle(.secondary)
                                    }
                                })
                            }
                        }
                    } header: {
                        Text(group.title)
                    }
                }
            }
        }
    }
}

struct ShadowSocksRView: View {
    @State var settings: LuCI.ShadowSocksRGroups?

    func getSettings() async throws {
        do {
            self.settings = try await LuCI.shared.getShadowSocks()
        } catch {
            self.settings = nil
        }
    }

    var list: some View {
        Group {
            if settings == nil {
                Text("(nothing here)").foregroundColor(.secondary)
            } else {
                ShadowSocksRSettingsView().environmentObject(settings!)
            }
        }
    }

    var body: some View {
        NavigationView {
            list
                .navigationTitle("ShadowSocksR")
                .refreshable {
                    Task {
                        try await getSettings()
                    }
                }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            Task {
                try await getSettings()
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
            ShadowSocksRView().tabItem {
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
