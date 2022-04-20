//
//  LuCIApp.swift
//  LuCI
//
//  Created by CGH on 2022/3/8.
//

import SwiftUI

@main
struct LuCIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    WatchSession.shared.watchUserDefaults()
                }
        }
    }
}
