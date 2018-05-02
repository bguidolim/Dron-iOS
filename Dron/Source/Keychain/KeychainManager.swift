//
//  File.swift
//  Dron
//
//  Created by Bruno Guidolim on 29.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import KeychainAccess

private struct KeychainKeys {
    static let ServiceKey = "com.guidolim.Dron"
    static let username = "Dron.username"
    static let password = "Dron.password"
}

struct KeychainManager {
    private static var manager: Keychain {
        return Keychain(service: KeychainKeys.ServiceKey).accessibility(.afterFirstUnlock)
    }

    static func saveUsername(_ username: String) {
        manager[KeychainKeys.username] = username
    }

    static func username() -> String? {
        return manager[KeychainKeys.username]
    }

    static func savePassword(_ password: String) {
        manager[KeychainKeys.password] = password
    }

    static func passwordRef() -> Data? {
        return manager[attributes: KeychainKeys.password]?.persistentRef
    }

    static func password() -> String? {
        return manager[KeychainKeys.password]
    }
}
