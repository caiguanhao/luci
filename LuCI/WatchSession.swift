//
//  WatchSession.swift
//  LuCI
//
//  Created by CGH on 2022/4/19.
//

import Foundation
import WatchConnectivity

class WatchSession: NSObject, WCSessionDelegate {
    static let shared = WatchSession()

    func watchUserDefaults() {
        addListener(name: "global", callback: { (sess, data, reply) in
            if let action = data["action"] as? String {
                if action == "getUserDefaults" {
                    if let keysStr = data["keys"] as? String,
                       let keys = [String].init(rawValue: keysStr) {
                        var bundle: [String: Any] = ["action": "setUserDefaults"]
                        for key in keys {
                            if let value = UserDefaults.standard.string(forKey: key) {
                                bundle[key] = value
                            }
                        }
                        reply(bundle)
                        return
                    }
                } else if action == "setUserDefaults" {
                    for (key, value) in data {
                        if key == "action" {
                            continue
                        }
                        if let value = value as? String {
                            UserDefaults.standard.set(value, forKey: key)
                        }
                    }
                    reply(["result": "SUCCESS"])
                    return
                }
            }
            reply(["result": "FAIL"])
        })
    }

    typealias onRecvMsg = (WCSession, [String : Any], @escaping ([String : Any]) -> Void) -> ()
    private var listeners = [String: onRecvMsg]()

    func addListener(name: String, callback: @escaping onRecvMsg) {
        if WCSession.default.activationState != .activated {
            if WCSession.isSupported() {
                WCSession.default.delegate = self
                WCSession.default.activate()
            }
        }
        listeners[name] = callback
    }

    func removeListener(name: String) {
        listeners.removeValue(forKey: name)
    }

    typealias onActivated = (WCSession, String?) -> ()
    private var callbacks = [onActivated]()

    func activate(_ callback: @escaping onActivated) {
        callbacks.append(callback)
        if WCSession.default.activationState == .activated {
            runCallbacks(session: WCSession.default, error: nil)
        } else {
            if WCSession.isSupported() {
                WCSession.default.delegate = self
                WCSession.default.activate()
            }
        }
    }

    private func runCallbacks(session: WCSession, error: Error?) {
        while callbacks.count > 0 {
            var errMsg: String? = nil
            if let err = error {
                errMsg = err.localizedDescription
            } else if session.activationState != .activated {
                errMsg = "Not activated"
            }
            #if os(watchOS)
            if errMsg == nil && !session.isCompanionAppInstalled {
                errMsg = "Phone app not installed"
            }
            #endif
            callbacks[0](session, errMsg)
            callbacks.remove(at: 0)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        runCallbacks(session: session, error: error)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        for (_, listener) in listeners {
            listener(session, message, replyHandler)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
