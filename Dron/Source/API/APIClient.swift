//
//  NordVPNAPIClient.swift
//  Dron
//
//  Created by Bruno Guidolim on 14.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import Foundation

final class NordAPIClient: HTTPClient {

    var baseURL: URL? {
        return URL(string: "https://api.nordvpn.com/")
    }
    var manager = SessionManager()

    deinit {
        manager.invalidateSession()
    }
}
