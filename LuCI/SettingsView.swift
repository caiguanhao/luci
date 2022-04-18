//
//  SettingsView.swift
//  LuCI
//
//  Created by CGH on 2022/3/19.
//

import Foundation
import SwiftUI

#if os(iOS)
import Introspect
#endif

struct EditAccountView: View {
    var account: LuCI.Account?
    var onSave: ((LuCI.Account) -> ())?
    var onDelete: (() -> ())?

    @Environment(\.presentationMode) var presentationMode

    @State private var name: String = ""
    @State private var host: String = LuCI.DEFAULT_HOST
    @State private var user: String = LuCI.DEFAULT_USER
    @State private var pass: String = LuCI.DEFAULT_PASS

    var saveButton: some View {
        Button("Save") {
            onSave?(LuCI.Account(name: name, host: host, user: user, pass: pass))
            presentationMode.wrappedValue.dismiss()
        }
        #if os(watchOS)
        .font(.system(size: 13))
        #endif
    }

    #if os(watchOS)
    private let factor = 0.6
    #else
    private let factor = 0.5
    #endif

    var body: some View {
        GeometryReader { metrics in
            List {
                Section {
                    HStack {
                        Text("Name")
                            #if os(watchOS)
                            .font(.system(size: 13))
                            #endif
                        Spacer()
                        TextField("Name", text: $name)
                            .frame(maxWidth: metrics.size.width * factor)
                            #if os(watchOS)
                            .scaleEffect(13.0/16.0)
                            #elseif os(iOS)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            #endif
                    }
                    HStack {
                        Text("Host")
                            #if os(watchOS)
                            .font(.system(size: 13))
                            #endif
                        Spacer()
                        TextField("Host", text: $host)
                            .frame(maxWidth: metrics.size.width * factor)
                            #if os(watchOS)
                            .scaleEffect(13.0/16.0)
                            #elseif os(iOS)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            #endif
                    }
                    HStack {
                        Text("User")
                            #if os(watchOS)
                            .font(.system(size: 13))
                            #endif
                        Spacer()
                        TextField("User", text: $user)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .frame(maxWidth: metrics.size.width * factor)
                            #if os(watchOS)
                            .scaleEffect(13.0/16.0)
                            #elseif os(iOS)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            #endif
                    }
                    HStack {
                        Text("Password")
                            #if os(watchOS)
                            .font(.system(size: 13))
                            #endif
                        Spacer()
                        SecureField("Password", text: $pass)
                            .frame(maxWidth: metrics.size.width * factor)
                            #if os(watchOS)
                            .scaleEffect(13.0/16.0)
                            #elseif os(iOS)
                            .introspectTextField { $0.clearButtonMode = .whileEditing }
                            #endif
                    }
                }
                #if os(watchOS)
                Section {
                    saveButton.foregroundColor(.green)
                }
                #endif
                if account != nil {
                    Section {
                        Button {
                            onDelete?()
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Delete").foregroundColor(.red)
                                #if os(watchOS)
                                .font(.system(size: 13))
                                #endif
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
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                saveButton
            }
        }
        #endif
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
                #if os(watchOS)
                .font(.system(size: 13))
                #endif
            Spacer()
            Image(systemName: image)
                #if os(watchOS)
                .imageScale(.medium)
                #else
                .imageScale(.large)
                #endif
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
                            #if os(watchOS)
                            .font(.system(size: 13))
                            #endif

                    })
                    #if os(watchOS)
                    if accounts.count > 0 {
                        editAccountsView
                    }
                    #endif
                } header: {
                    HStack {
                        Text("Accounts")
                        #if os(iOS)
                        if accounts.count > 0 {
                            Spacer()
                            editAccountsView
                        }
                        #endif
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
            #if os(iOS)
            .toolbar {
                EditButton()
            }
            #endif
        }, label: {
            #if os(watchOS)
            Text("Edit Accounts").foregroundColor(.green)
                .font(.system(size: 13))
            #else
            Text("Edit")
            #endif
        })
    }
}
