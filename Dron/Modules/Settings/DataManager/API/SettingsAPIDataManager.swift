//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import RxSwift

class SettingsAPIDataManager: SettingsAPIDataManagerInputProtocol {
    init() {}

    let api = NordAPIClient()

    func getServers() -> Observable<[Server]> {
        return api.request(Server.Resource.getServers)
    }
}
