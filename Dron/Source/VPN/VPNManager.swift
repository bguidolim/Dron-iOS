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
        get {
            return UserDefaults.standard.string(forKey: DefaultKeys.CurrentServer)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultKeys.CurrentServer)
        }
    }
    private var isConnecting = false
    private let vpnManager = NEVPNManager.shared()
    private let apiClient = NordAPIClient()

    // MARK: - Init & Deinit

    init() {
        vpnManager.localizedDescription = "Dron"
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public methods

    func start() {
        load()
            .then { _ in
                NotificationCenter.default.addObserver(self,
                                                       selector: #selector(self.vpnStatusDidChange(_:)),
                                                       name: .NEVPNStatusDidChange,
                                                       object: nil)
            }
            .onError { error in
                // TODO
                print(error.localizedDescription)
        }
    }

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

                let configuration = NEVPNProtocolIKEv2()
                configuration.remoteIdentifier = server.domain
                configuration.localIdentifier = server.name
                configuration.serverAddress = server.ipAddress
                configuration.username = KeychainManager.username()
                configuration.passwordReference = KeychainManager.passwordRef()
                configuration.useExtendedAuthentication = true
                configuration.disconnectOnSleep = false
                self.vpnManager.protocolConfiguration = configuration
                self.vpnManager.isEnabled = true
                self.configureKillSwitch(enabled: configureKillSwitch)

                self.load()
                    .validate(withError: VPNError.alreadyConnectedToServer, { [weak self] _ -> Bool in
                        guard let currentServer = self?.currentServer else {
                            return true
                        }
                        return currentServer != server.domain
                    })
                    .then(self.save())
                    .then(self.connect())
                    .onError { error in
                        promise.reject(error)
                    }
                    .finally {
                        UserDefaults.standard.set(server.domain,
                                                  forKey: DefaultKeys.CurrentServer)
                        promise.fulfill(nil)
                }
        }

        return promise
    }

    func disconnect() {
        isConnecting = false
        configureKillSwitch(enabled: false)
        save().finally { [weak self] in
            self?.vpnManager.connection.stopVPNTunnel()
            self?.currentServer = nil
        }
    }

    func configureKillSwitch(enabled: Bool) {
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

    // MARK: - Private methods

    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let obj = notification.object as? NEVPNConnection else {
            return
        }

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

        if obj.status == .disconnected {
            if self.isConnecting {
                try? obj.startVPNTunnel()
            }
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
        if vpnManager.connection.status == .connected {
            self.disconnect()
        }
        let promise = Promise<Any?>()
        do {
            promise.fulfill(try vpnManager.connection.startVPNTunnel())
        } catch {
            promise.reject(error)
        }
        return promise
    }
}
