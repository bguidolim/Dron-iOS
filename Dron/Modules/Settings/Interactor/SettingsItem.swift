//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import RxSwift

struct SettingsItem {
    let username: String?
    let password: String?
    let country: String?

    init(username: String? = nil,
         password: String? = nil,
         country: String? = nil) {
        self.username = username
        self.password = password
        self.country = country
    }
}
