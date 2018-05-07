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

    // MARK: - Init & Deinit

    init() {
        vpnManager.localizedDescription = "Dron"
        currentServer = UserDefaults.standard.string(forKey: DefaultKeys.CurrentServer)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.vpnStatusDidChange(_:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.loadVPNConfig),
                                               name: .UIApplicationDidBecomeActive,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.loadVPNConfig),
                                               name: .NEVPNConfigurationChange,
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
                        promise.fulfill(nil)
                    }
                    .onError { error in
                        promise.reject(error)
                }
        }

        return promise
    }

    func disconnect() -> Promise<Any?> {
        vpnManager.connection.stopVPNTunnel()
        currentServer = nil
        configureKillSwitch(enabled: false)

        let promise = Promise<Any?>()
        save()
            .then { _ in
                promise.fulfill(nil)
            }
            .onError { error in
                promise.reject(error)
        }
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
    }

    @objc private func loadVPNConfig() {
        _ = load()
    }

    private func setupProtocol(with server: Server) -> NEVPNProtocolIKEv2 {
        let configuration = NEVPNProtocolIKEv2()
        configuration.remoteIdentifier = server.domain
        configuration.localIdentifier = server.name
        configuration.serverAddress = server.ipAddress
        configuration.username = KeychainManager.username()
        configuration.passwordReference = KeychainManager.passwordRef()
        configuration.useExtendedAuthentication = true
        configuration.disconnectOnSleep = false

        return configuration
    }

    private func configureKillSwitch(enabled: Bool) {
        vpnManager.isOnDemandEnabled = enabled
        if enabled {
            let wifiRule = NEOnDemandRuleConnect()
            wifiRule.interfaceTypeMatch = .wiFi

            let cellularRule = NEOnDemandRuleConnect()
            cellularRule.interfaceTypeMatch = .cellular

            vpnManager.onDemandRules = [wifiRule, cellularRule]
        } else {
            vpnManager.onDemandRules = nil
        }
    }

    private func load() -> Promise<Any?> {
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
            promise.fulfill(try self.vpnManager.connection.startVPNTunnel())
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
