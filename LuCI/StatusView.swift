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
    @AppStorage("currentStatus") private var groups = [LuCI.StatusGroup]() {
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
            self.groups = [LuCI.StatusGroup]()
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
    var groups: [LuCI.StatusGroup]

    var body: some View {
        ForEach(groups) { group in
            Section {
                if group.isEmpty, let msg = group.emptyMessage {
                    Text(msg).foregroundColor(.secondary)
                }
                ForEach(group.statuses) { status in
                    VStack {
                        HStack {
                            Text(status.key)
                                #if os(watchOS)
                                .font(.system(size: 13))
                                #endif
                            Spacer()
                            Text(status.value)
                                .multilineTextAlignment(.trailing)
                                .frame(width: width * 0.5, alignment: .trailing)
                                .foregroundStyle(.secondary)
                                #if os(watchOS)
                                .font(.system(size: 13))
                                .minimumScaleFactor(0.6)
                                .lineLimit(3)
                                #else
                                .lineLimit(2)
                                .minimumScaleFactor(0.5)
                                #endif
                        }
                    }
                }
            } header: {
                Text(group.name)
            }
        }
    }
}
