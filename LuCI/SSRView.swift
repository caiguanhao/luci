//
//  SSRView.swift
//  LuCI
//
//  Created by CGH on 2022/4/1.
//

import Foundation
import SwiftUI

struct SSRView: View {
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
                List {
                    VStack {
                        Text("(nothing here)").foregroundColor(.secondary)
                    }.listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            } else {
                SSRSettingsView().environmentObject(settings!)
            }
        }
    }

    var body: some View {
        NavigationView {
            list
                .navigationTitle("ShadowSocksR")
                .refreshable {
                    try? await getSettings()
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

struct SSRSettingsView: View {
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
                                        SSROptionView(groupIdx: groupIdx,
                                                      settingIdx: settingIdx)
                                            .environmentObject(settings)
                                            .environmentObject(LuCI.ShadowSocksRServers())
                                    }.navigationTitle(setting.title)
                                        .introspectTableView {
                                            // smaller section spacing
                                            $0.sectionHeaderHeight = 0
                                            $0.sectionHeaderTopPadding = 0
                                        }
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

struct SSROptionView: View {
    @EnvironmentObject var settings: LuCI.ShadowSocksRGroups
    @Environment(\.presentationMode) var presentationMode

    let groupIdx: Int
    let settingIdx: Int

    var setting: LuCI.ShadowSocksRSetting {
        return settings.groups[groupIdx].settings[settingIdx]
    }

    var canTestServers: Bool {
        return setting.name.hasSuffix(".global_server")
    }

    @State var testStarted: Bool = false

    @EnvironmentObject private var servers: LuCI.ShadowSocksRServers

    var body: some View {
        if canTestServers {
            SSRTestConnView(testStarted: $testStarted)
        }
        Section {
            ForEach(setting.options.indices, id: \.self) { index in
                VStack {
                    Button(action: {
                        settings.groups[groupIdx].settings[settingIdx].selectedIndex = index
                        self.presentationMode.wrappedValue.dismiss()
                    }, label: {
                        HStack {
                            Text(setting.options[index].title)
                                .foregroundColor(index == setting.selectedIndex ? .accentColor : .primary)
                            if canTestServers && testStarted {
                                Spacer()
                                SSRLatencyView(id: setting.options[index].value)
                            }
                        }
                    })
                }
            }
        }
    }
}

struct SSRTestConnView: View {
    @EnvironmentObject private var servers: LuCI.ShadowSocksRServers

    @Binding var testStarted: Bool
    @State var testing: Bool = false

    var body: some View {
        Section {
            Button(action: {
                testStarted = true
                if testing {
                    LuCI.shared.cancelAll()
                    testing = false
                    return
                }
                Task {
                    testing = true
                    servers.removeAll()
                    let srvs = try await LuCI.shared.getShadowSocksRServerNodes()
                    do {
                        try await withThrowingTaskGroup(of: (Int, (Bool, Int)).self) { group in
                            let total = srvs.count
                            let batchSize = min(total, 5)
                            for index in 0..<batchSize {
                                srvs[index].testing = true
                                servers.append(srvs[index])
                                group.addTask {
                                    let (con, lat) = try await LuCI.shared.pingServer(srvs[index])
                                    return (index, (con, lat))
                                }
                            }
                            var index = batchSize
                            for try await (i, (socketConnected, pingLatency)) in group {
                                srvs[i].testing = false
                                srvs[i].socketConnected = socketConnected
                                srvs[i].pingLatency = pingLatency
                                servers.update(srvs[i])
                                if index < total {
                                    srvs[index].testing = true
                                    servers.append(srvs[index])
                                    group.addTask { [index] in
                                        let (con, lat) = try await LuCI.shared.pingServer(srvs[index])
                                        return (index, (con, lat))
                                    }
                                    index += 1
                                }
                            }
                        }
                    } catch {
                        for i in srvs.indices {
                            if srvs[i].testing {
                                srvs[i].testing = false
                                servers.update(srvs[i])
                            }
                        }
                    }
                    testing = false
                }
            }, label: {
                HStack {
                    Text(testing ? "Cancel" : "Run Connectivity Test")
                        .foregroundColor(testing ? .red : .green)
                    if testing {
                        Spacer()
                        ProgressView()
                    }
                }
            })
        }.onDisappear {
            LuCI.shared.cancelAll()
        }
    }
}

struct SSRLatencyView: View {
    var id: String

    @EnvironmentObject private var servers: LuCI.ShadowSocksRServers

    var server: LuCI.ShadowSocksRServer? {
        for srv in servers.servers {
            if srv.server.id == id {
                return srv
            }
        }
        return nil
    }

    var text: String {
        if server?.server.domain == nil {
            return ""
        }
        if self.server!.pingLatency == nil {
            return "-"
        }
        return "\(self.server!.pingLatency!)ms"
    }

    var color: Color {
        if self.server == nil || self.server!.pingLatency == nil {
            return .gray
        }
        let lat = self.server!.pingLatency!
        if lat < 100 {
            return .green
        }
        if lat < 200 {
            return .orange
        }
        return .red
    }

    var body: some View {
        if self.server != nil && self.server!.testing {
            ProgressView().frame(width: 60, alignment: .trailing)
        } else {
            Text(text)
                .foregroundColor(color)
                .font(.system(size: 12))
                .frame(width: 60, alignment: .trailing)
        }
    }
}