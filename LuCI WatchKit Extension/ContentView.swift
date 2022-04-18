//
//  ContentView.swift
//  LuCI WatchKit Extension
//
//  Created by CGH on 2022/3/8.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("tabSelection") private var selection: Int = 1

    var body: some View {
        TabView(selection: $selection) {
            StatusView().tabItem {
                Text("Status")
            }.tag(1)
            SSRView().tabItem {
                Text("SSR")
            }.tag(2)
            NetworkView().tabItem {
                Text("Network")
            }.tag(3)
            SettingsView().tabItem {
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
