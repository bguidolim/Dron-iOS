//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation

struct SettingsItem {
    let username: String?
    let password: String?
    let country: String?
    let killSwitch: Bool

    init(username: String? = nil,
         password: String? = nil,
         country: String? = nil,
         killSwitch: Bool = false) {
        self.username = username
        self.password = password
        self.country = country
        self.killSwitch = killSwitch
    }
}
