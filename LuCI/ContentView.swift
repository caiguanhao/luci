//
//  ContentView.swift
//  LuCI
//
//  Created by CGH on 2022/3/8.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("tabSelection") private var selection: Int = 1

    var body: some View {
        TabView(selection: $selection) {
            StatusView().tabItem {
                Image(systemName: "wifi")
                Text("Status")
            }.tag(1)
            SSRView().tabItem {
                Image(systemName: "paperplane")
                Text("SSR")
            }.tag(2)
            NetworkView().tabItem {
                Image(systemName: "network")
                Text("Network")
            }.tag(3)
            SettingsView().tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }.tag(4)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
