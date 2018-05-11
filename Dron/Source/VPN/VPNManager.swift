//
//  VPNManager.swift
//  Dron
//
//  Created by Bruno Guidolim on 15.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import NetworkExtension
import then

private struct DefaultKeys {
    static let CurrentServer = "CurrentServer"
}

enum VPNError: Error {
    case invalidServer
    case alreadyConnectedToServer
}

final class VPN {
    static let manager = VPN()
    var status: NEVPNStatus {
        return vpnManager.connection.status
    }
    var currentServer: String? {
        didSet {
            UserDefaults.standard.set(currentServer, forKey: DefaultKeys.CurrentServer)
        }
    }
    private var vpnManager = NEVPNManager.shared()
    private let apiClient = NordAPIClient()

    private var connectPromise = Promise<Any?>()
    private var disconnectPromise = Promise<Any?>()

    private var backgroundTask: Bool {
        return UIApplication.shared.applicationState == .background
    }

    // MARK: - Init & Deinit

    init() {
        vpnManager.localizedDescription = "Dron"
        currentServer = UserDefaults.standard.string(forKey: DefaultKeys.CurrentServer)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.vpnStatusDidChange(_:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.loadVPNConfiguration),
                                               name: .NEVPNConfigurationChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.loadVPNConfiguration),
                                               name: .UIApplicationDidBecomeActive,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public methods

    func connect(to country: String,
                 configureKillSwitch: Bool = false) -> Promise<Any?> {

        let promise = Promise<Any?>()
        let getServers: Promise<[Server]> = apiClient.request(Server.Resource.getServers)
        getServers
            .retry(3)
            .then { [unowned self] servers in
                guard let server = servers
                    .filter({ $0.country == country && $0.features.ikev2 == true })
                    .sorted(by: { (obj1, obj2) -> Bool in
                        return obj1.load < obj2.load
                    }).first else {
                        promise.reject(VPNError.invalidServer)
                        return
                }

                if let currentServer = self.currentServer, currentServer == server.domain {
                    promise.reject(VPNError.alreadyConnectedToServer)
                    return
                }

                self.disconnectIfNeeded()
                    .then { [weak self] _ in
                        self?.vpnManager.protocolConfiguration = self?.setupProtocol(with: server)
                        self?.vpnManager.isEnabled = true
                        self?.configureKillSwitch(enabled: configureKillSwitch)
                    }
                    .then(self.save())
                    .then(self.connect())
                    .then { [weak self] _ in
                        self?.currentServer = server.domain
                    }
                    .onError { error in
                        promise.reject(error)
                }
            }
            .onError { error in
                // TODO
                print("HTTP ERROR: \(error.localizedDescription)")
        }

        connectPromise = promise
        return promise
    }

    func disconnect() -> Promise<Any?> {
        vpnManager.connection.stopVPNTunnel()
        let promise  = Promise<Any?>()
        promise.then { [weak self] _ in
            self?.currentServer = nil
            self?.configureKillSwitch(enabled: false)

            self?.save()
                .then { _ in
                    promise.fulfill(nil)
                }
                .onError { error in
                    promise.reject(error)
            }
        }

        disconnectPromise = promise
        return promise
    }

    // MARK: - Private methods

    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let obj = notification.object as? NEVPNConnection else {
            return
        }

        #if DEBUG
        var status: String
        switch obj.status {
        case .connected:
            status = "Connected"
        case .connecting:
            status = "Connecting"
        case .disconnected:
            status = "Disconnected"
        case .disconnecting:
            status = "Disconnecting"
        case .invalid:
            status = "Invalid"
        case .reasserting:
            status = "Reasserting"
        }
        print("VPN Status: \(status)")
        #endif

        if obj.status == .disconnected {
            if backgroundTask {
                disconnectPromise.then(connect())
            }
            disconnectPromise.fulfill(nil)
        }

        if obj.status == .connected {
            connectPromise.fulfill(nil)
        }
    }

    @objc private func loadVPNConfiguration() {
        _ = load()
    }

    private func setupProtocol(with server: Server) -> NEVPNProtocolIKEv2 {
        let configuration = NEVPNProtocolIKEv2()
        configuration.remoteIdentifier = server.domain
        configuration.localIdentifier = server.name
        configuration.serverAddress = server.domain
        configuration.username = KeychainManager.username()
        configuration.passwordReference = KeychainManager.passwordRef()
        configuration.useExtendedAuthentication = true
        configuration.disconnectOnSleep = false

        return configuration
    }

    private func configureKillSwitch(enabled: Bool) {
        vpnManager.isOnDemandEnabled = enabled
        if enabled {
            let killSwitchRule = NEOnDemandRuleConnect()
            killSwitchRule.interfaceTypeMatch = .any

            vpnManager.onDemandRules = [killSwitchRule]
        } else {
            vpnManager.onDemandRules = nil
        }
    }

    func load() -> Promise<Any?> {
        let promise = Promise<Any?>()
        vpnManager.loadFromPreferences(completionHandler: { error in
            guard let error = error else {
                promise.fulfill(nil)
                return
            }
            promise.reject(error)
        })
        return promise
    }

    private func save() -> Promise<Any?> {
        let promise = Promise<Any?>()
        vpnManager.saveToPreferences { error in
            guard let error = error else {
                promise.fulfill(nil)
                return
            }
            promise.reject(error)
        }
        return promise
    }

    private func connect() -> Promise<Any?> {
        let promise = Promise<Any?>()
        do {
            try vpnManager.connection.startVPNTunnel()
            promise.fulfill(nil)
        } catch {
            promise.reject(error)
        }
        return promise
    }

    private func disconnectIfNeeded() -> Promise<Any?> {
        if vpnManager.connection.status == .connected {
            return disconnect()
        }
        return Promise.resolve(nil)
    }
}
