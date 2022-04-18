//
//  SettingsView.swift
//  LuCI
//
//  Created by CGH on 2022/3/19.
//

import Foundation
import SwiftUI
import Introspect

struct EditAccountView: View {
    var account: LuCI.Account?
    var onSave: ((LuCI.Account) -> ())?
    var onDelete: (() -> ())?

    @Environment(\.presentationMode) var presentationMode

    @State private var name: String = ""
    @State private var host: String = LuCI.DEFAULT_HOST
    @State private var user: String = LuCI.DEFAULT_USER
    @State private var pass: String = LuCI.DEFAULT_PASS

    var body: some View {
        GeometryReader { metrics in
            List {
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $name)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                    HStack {
                        Text("Host")
                        Spacer()
                        TextField("Host", text: $host)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                    HStack {
                        Text("User")
                        Spacer()
                        TextField("User", text: $user)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                    HStack {
                        Text("Password")
                        Spacer()
                        SecureField("Password", text: $pass)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            .frame(maxWidth: metrics.size.width * 0.5)
                    }
                }
                if account != nil {
                    Section {
                        Button {
                            onDelete?()
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Delete").foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .onAppear {
            if let acc = account {
                name = acc.name
                host = acc.host
                user = acc.user
                pass = acc.pass
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    onSave?(LuCI.Account(name: name, host: host, user: user, pass: pass))
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage(LuCI.STORAGE_ACCOUNTS) private var accounts = [LuCI.Account]()
    @AppStorage(LuCI.STORAGE_CURRENT_ACCOUNT_ID) private var currentAccountId = ""
    @State private var mode: action = .normal

    enum action {
        case normal, edit, move
        var next: action {
            switch self {
            case .normal: return .edit
            case .edit:   return .move
            case .move:   return .normal
            }
        }
        var title: String {
            switch self {
            case .normal: return "Accounts"
            case .edit:   return "Edit Account"
            case .move:   return "Move or Delete Account"
            }
        }
        var description: String {
            switch self {
            case .normal: return "Done"
            case .edit:   return "Edit..."
            case .move:   return "Move..."
            }
        }
    }

    private var selectedAny: Bool {
        for account in accounts {
            if account.id.uuidString == currentAccountId {
                return true
            }
        }
        return false
    }

    private func setCurrent(_ account: LuCI.Account? = nil) {
        var acc = account
        if acc == nil {
            acc = accounts.first
        }
        if !selectedAny && acc != nil {
            currentAccountId = acc!.id.uuidString
        }
        if accounts.count == 0 && mode != .normal {
            mode = .normal
        }
    }

    private func accountItemView(_ account: LuCI.Account) -> some View {
        let image = currentAccountId == account.id.uuidString ? "checkmark.circle.fill" : "circle"
        return HStack {
            Image(systemName: image).imageScale(.large)
            Text(account.display)
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(accounts) { account in
                        VStack {
                            switch mode {
                            case .normal:
                                Button {
                                    currentAccountId = account.id.uuidString
                                } label: {
                                    accountItemView(account)
                                }.foregroundColor(.primary).swipeActions {}
                            case .edit:
                                NavigationLink(destination: {
                                    EditAccountView(account: account, onSave: { newAccount in
                                        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
                                            accounts[idx] = newAccount
                                            setCurrent(newAccount)
                                        }
                                    }, onDelete: {
                                        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
                                            accounts.remove(at: idx)
                                            setCurrent()
                                        }
                                    }).navigationTitle("Edit Account")
                                }, label: {
                                    accountItemView(account)
                                }).swipeActions {}
                            case .move:
                                Button {
                                } label: {
                                    accountItemView(account)
                                }.foregroundColor(.primary)
                            }
                        }
                    }
                    .onMove { accounts.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { accounts.remove(atOffsets: $0); setCurrent() }
                    NavigationLink(destination: {
                        EditAccountView(onSave: { account in
                            accounts.append(account)
                            setCurrent(account)
                        }).navigationTitle("New Account")
                    }, label: {
                        Text("Add New").foregroundColor(.green)
                    })
                } header: {
                    HStack {
                        Text(mode.title)
                        if accounts.count > 0 {
                            Spacer()
                            Button {
                                mode = mode.next
                            } label: {
                                Text(mode.next.description)
                            }
                        }
                    }
                }
            }.navigationTitle("Settings")
                .environment(\.editMode, .constant(mode == .move ? .active : .inactive))
                .animation(.linear, value: mode == .move)
        }.navigationViewStyle(.stack)
    }
}

func BetterText(_ content: String, width: CGFloat) -> some View {
    return Text(content)
        .multilineTextAlignment(.trailing)
        .frame(width: width, alignment: .trailing)
        .lineLimit(2)
        .minimumScaleFactor(0.5)
        .foregroundStyle(.secondary)
}
