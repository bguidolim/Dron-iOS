//
//  Models.swift
//  Dron
//
//  Created by Bruno Guidolim on 15.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import CoreLocation

public struct Server: Codable {
    let id: Int
    let name: String
    let domain: String
    let ipAddress: String
    let flag: String
    let country: String
    let location: Location
    let load: Double
    let features: Features
}

extension Server {
    enum Resource: HTTPResource {
        case getServers

        var path: String {
            switch self {
            case .getServers:
                return "server"
            }
        }
    }
}

struct Location: Codable {
    let lat: Double
    let long: Double
}

struct Features: Codable {
    let ikev2: Bool
}

struct Country: Codable, Hashable {
    let flag: String
    let country: String
}
