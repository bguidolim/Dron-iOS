//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import then

class SettingsAPIDataManager: SettingsAPIDataManagerInputProtocol {
    init() {}

    let api = NordAPIClient()

    func getServers() -> Promise<[Server]> {
        return api.request(Server.Resource.getServers)
    }
}
