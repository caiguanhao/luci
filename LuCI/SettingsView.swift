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
    }

    private func accountItemView(_ account: LuCI.Account) -> some View {
        let image = currentAccountId == account.id.uuidString ? "checkmark.circle.fill" : "circle"
        return HStack {
            Text(account.display)
            Spacer()
            Image(systemName: image).imageScale(.large)
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(accounts) { account in
                        Button {
                            currentAccountId = account.id.uuidString
                        } label: {
                            accountItemView(account)
                        }.foregroundColor(.primary).swipeActions {}
                    }
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
                        Text("Accounts")
                        if accounts.count > 0 {
                            Spacer()
                            editAccountsView
                        }
                    }
                }
            }.navigationTitle("Settings")
        }.navigationViewStyle(.stack)
    }

    var editAccountsView: some View {
        NavigationLink(destination: {
            List {
                ForEach(accounts) { account in
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
                    })
                }
                .onMove { accounts.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { accounts.remove(atOffsets: $0); setCurrent() }
            }
            .navigationTitle("Edit Accounts")
            .toolbar {
                EditButton()
            }
        }, label: {
            Text("Edit")
        })
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
