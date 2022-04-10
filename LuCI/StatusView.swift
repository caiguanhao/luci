//
//  StatusView.swift
//  LuCI
//
//  Created by CGH on 2022/4/2.
//

import Foundation
import SwiftUI

struct StatusView: View {
    @State private var groupSize = 0
    @AppStorage("currentStatus") private var groups = LuCI.StatusGroups() {
        didSet {
            groupSize = groups.count
        }
    }
    @State private var errorMsg: String?

    func getStatus() async throws {
        do {
            self.groups = try await LuCI.shared.getStatus()
            self.errorMsg = nil
        } catch {
            self.groups = LuCI.StatusGroups()
            self.errorMsg = error.localizedDescription
        }
    }

    var body: some View {
        NavigationView {
            GeometryReader { metrics in
                List {
                    if errorMsg == nil {
                        StatusListView(width: metrics.size.width, groups: groups)
                    } else {
                        VStack {
                            Text("Error: \(self.errorMsg!)").foregroundColor(.red)
                        }.listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
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

struct StatusListView: View {
    var width: CGFloat
    var groups: LuCI.StatusGroups

    var body: some View {
        ForEach(groups) { group in
            Section {
                ForEach(group.statuses) { status in
                    VStack {
                        HStack {
                            Text(status.key)
                            Spacer()
                            Text(status.value)
                                .multilineTextAlignment(.trailing)
                                .frame(width: width * 0.5, alignment: .trailing)
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
