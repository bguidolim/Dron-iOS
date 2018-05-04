//
//  HTTPProtocols.swift
//  Dron
//
//  Created by Bruno Guidolim on 14.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import then

struct HTTPTarget<R: HTTPResource>: HTTPTargetProtocol {
    let baseURL: URL?
    let resource: R
}

extension HTTPTargetProtocol {
    var URL: URL? {
        return baseURL?.appendingPathComponent(resource.path)
    }
}

// MARK: - Protocols

public protocol HTTPClient {
    var baseURL: URL? { get }
    var manager: SessionManager { get }
}

public protocol HTTPResource {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: Parameters? { get }
    var useCache: Bool { get }
}

public protocol HTTPTargetProtocol {
    associatedtype Resource: HTTPResource
    var baseURL: URL? { get }
    var resource: Resource { get }
}

// MARK: Extensions

public extension HTTPClient {
    private func request<T: HTTPTargetProtocol>(_ target: T) -> Promise<Data> {
        return manager.request(url: target.URL,
                               method: target.resource.method,
                               params: target.resource.parameters,
                               useCache: target.resource.useCache)
    }

    public func request<R: HTTPResource, T: Decodable>(_ resource: R) -> Promise<T> {
        let target = HTTPTarget(baseURL: baseURL, resource: resource)
        let promise = Promise<T>()
        request(target).then { data in
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                promise.fulfill(try decoder.decode(T.self, from: data))
            } catch {
                promise.reject(error)
            }
        }
        return promise
    }
}

public extension HTTPResource {
    var method: HTTPMethod {
        return .get
    }

    var parameters: Parameters? {
        return nil
    }

    var useCache: Bool {
        return true
    }
}
