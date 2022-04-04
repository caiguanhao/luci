//
//  StatusView.swift
//  LuCI
//
//  Created by CGH on 2022/4/2.
//

import Foundation
import SwiftUI

struct StatusView: View {
    @State var groups: [LuCI.StatusGroup]?

    func getStatus() async throws {
        do {
            self.groups = try await LuCI.shared.getStatus()
        } catch {
            self.groups = nil
        }
    }

    var body: some View {
        NavigationView {
            GeometryReader { metrics in
                List {
                    if groups == nil {
                        VStack {
                            Text("(failed to get status)").foregroundColor(.secondary)
                        }.listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    } else {
                        StatusListView(width: metrics.size.width, groups: groups!)
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
    var groups: [LuCI.StatusGroup]

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
