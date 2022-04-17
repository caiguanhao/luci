//
//  SSRView.swift
//  LuCI
//
//  Created by CGH on 2022/4/1.
//

import Foundation
import SwiftUI

struct SSRView: View {
    @AppStorage("currentSSR") var settings = LuCI.ShadowSocksRGroups()
    @State private var errorMsg: String?

    func getSettings() async throws {
        do {
            let isOnOptionsPage = self.settings.isOnOptionsPage
            self.settings = try await LuCI.shared.getShadowSocks()
            self.settings.isOnOptionsPage = isOnOptionsPage
            self.errorMsg = nil
        } catch {
            self.settings = LuCI.ShadowSocksRGroups()
            self.errorMsg = error.localizedDescription
        }
    }

    @State private var running = false

    var list: some View {
        Group {
            if errorMsg == nil {
                SSRSettingsView().environmentObject(settings)
                    .introspectNavigationController { nav in
                        let bar = nav.navigationBar
                        let hosting = UIHostingController(
                            rootView: SSRRunningView(running: $running).environmentObject(settings)
                        )
                        guard let hostingView = hosting.view else { return }
                        bar.addSubview(hostingView)
                        hostingView.backgroundColor = .clear
                        lastHostingView?.removeFromSuperview()
                        lastHostingView = hostingView
                        hostingView.translatesAutoresizingMaskIntoConstraints = false
                        NSLayoutConstraint.activate([
                            hostingView.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -20),
                            hostingView.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -12)
                        ])

                    }
            } else {
                List {
                    VStack {
                        Text("Error: \(self.errorMsg!)").foregroundColor(.red)
                    }.listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
    }

    @State private var lastHostingView: UIView?

    var body: some View {
        NavigationView {
            list
                .navigationTitle("SSR")
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

struct SSRRunningView: View {
    @EnvironmentObject var settings: LuCI.ShadowSocksRGroups

    @Binding var running: Bool
    @State private var timer: Timer?

    func stop() {
        timer?.invalidate()
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            Task {
                self.running = try await LuCI.shared.checkRunning()
            }
        }
    }

    var body: some View {
        Text(running ? "Running" : "Stopped")
            .foregroundColor(running ? .green : .red)
            .frame(width: 200, alignment: .trailing)
            .opacity(settings.isOnOptionsPage ? 0 : 1)
            .onChange(of: settings.isOnOptionsPage) { onOptionsPage in
                stop()
                if !onOptionsPage {
                    start()
                }
            }
            .onAppear {
                start()
            }
            .onDisappear {
                stop()
            }
    }
}

struct SSRSettingsView: View {
    @EnvironmentObject var settings: LuCI.ShadowSocksRGroups

    var body: some View {
        GeometryReader { metrics in
            List {
                ForEach(settings.groups) { group in
                    SSRSettingView(group: group, width: metrics.size.width * 0.4)
                }
            }
        }
    }
}

struct SSRSettingView: View {
    @EnvironmentObject var settings: LuCI.ShadowSocksRGroups

    let group: LuCI.ShadowSocksRGroup
    let width: CGFloat

    @State private var saving = false

    var body: some View {
        Section {
            ForEach(group.settings.indices) { settingIdx in
                let setting = group.settings[settingIdx]
                VStack {
                    NavigationLink(destination: {
                        SSROptionsView(group: group, settingIdx: settingIdx)
                            .environmentObject(settings)
                    }, label: {
                        HStack {
                            Text(setting.title)
                            Spacer()
                            Text(setting.valueText)
                                .multilineTextAlignment(.trailing)
                                .frame(width: width, alignment: .trailing)
                                .lineLimit(2)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(.secondary)
                        }
                    })
                }
            }
            if group.hasChanaged {
                Button(action: {
                    Task {
                        saving = true
                        do {
                            let updated = try await LuCI.shared.updateSSRSettings(group)
                            settings.groups = updated.groups
                        } catch {
                            print(error)
                        }
                        saving = false
                    }
                }, label: {
                    HStack {
                        Text("Save & Apply").foregroundColor(saving ? .secondary : .green)
                        if saving {
                            Spacer()
                            ProgressView()
                        }
                    }
                }).disabled(saving)
            }
        } header: {
            Text(group.title)
        }
    }
}

struct SSROptionsView: View {
    let group: LuCI.ShadowSocksRGroup
    let settingIdx: Int

    @EnvironmentObject var settings: LuCI.ShadowSocksRGroups
    @Environment(\.isPresented) var isPresented

    var body: some View {
        let setting = group.settings[settingIdx]
        List {
            SSROptionView(group: group,
                          settingIdx: settingIdx)
                .environmentObject(settings)
                .environmentObject(LuCI.ShadowSocksRServers())
        }
        .navigationTitle(setting.title)
        .onDisappear {
            LuCI.shared.cancelAll()
        }
        .introspectTableView {
            // smaller section spacing
            $0.sectionHeaderHeight = 0
            $0.sectionHeaderTopPadding = 0
        }
        .onAppear {
            if isPresented {
                settings.isOnOptionsPage = true
            }
        }
        .onChange(of: isPresented) {
            settings.isOnOptionsPage = $0
        }
    }
}

struct SSROptionView: View {
    @EnvironmentObject var settings: LuCI.ShadowSocksRGroups
    @Environment(\.presentationMode) var presentationMode

    let group: LuCI.ShadowSocksRGroup
    let settingIdx: Int

    var setting: LuCI.ShadowSocksRSetting {
        return group.settings[settingIdx]
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
                        settings.setSelected(group: group, settingIndex: settingIdx, index: index)
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
