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

final class VPN {
    static let manager = VPN()
    var status: NEVPNStatus {
        return vpnManager.connection.status
    }
    var currentServer: String? {
        return UserDefaults.standard.string(forKey: DefaultKeys.CurrentServer)
    }
    private var isConnecting = false
    private let vpnManager = NEVPNManager.shared()
    private let apiClient = NordAPIClient()

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        load().then { _ in
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(self.vpnStatusDidChange(_:)),
                                                   name: .NEVPNStatusDidChange,
                                                   object: nil)
            }.onError { error in
                // TODO
                print(error.localizedDescription)
        }
    }

    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let obj = notification.object as? NEVPNConnection else {
            return
        }
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

    private func save(_ configuration: NEVPNProtocolIKEv2) -> Promise<Any?> {
        vpnManager.localizedDescription = "Dron"
        vpnManager.isEnabled = true

        configuration.useExtendedAuthentication = true
        configuration.disconnectOnSleep = false
        vpnManager.protocolConfiguration = configuration

        let promise = Promise<Any?>()
        vpnManager.saveToPreferences(completionHandler: { error in
            guard let error = error else {
                promise.fulfill(nil)
                return
            }
            promise.reject(error)
        })
        return promise
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

    private func connect() -> Promise<Any?> {
        let promise = Promise<Any?>()
        do {
            promise.fulfill(try vpnManager.connection.startVPNTunnel())
        } catch {
            promise.reject(error)
        }
        return promise
    }

    private func connect(with configuration: NEVPNProtocolIKEv2) {
        isConnecting = true
        save(configuration)
            .then(connect())
            .onError { error in
                // TODO
                print(error.localizedDescription)
        }
    }

    func connectToBestServer(_ server: Server,
                             killSwitchEnabled: Bool = false,
                             backgroundAction: Bool = false) {
        if let currentServer = self.currentServer,
            vpnManager.connection.status == .connected {
            if server.domain != currentServer {
                VPN.manager.disconnect()
            }
        }

        if vpnManager.connection.status == .disconnected && backgroundAction {
            return
        }

        let configuration = NEVPNProtocolIKEv2()
        configuration.remoteIdentifier = server.domain
        configuration.localIdentifier = server.name
        configuration.serverAddress = server.ipAddress
        configuration.username = KeychainManager.username()
        configuration.passwordReference = KeychainManager.passwordRef()

        if !backgroundAction {
            configureKillSwitch(enabled: killSwitchEnabled)
        }

        UserDefaults.standard.set(server.domain, forKey: DefaultKeys.CurrentServer)
        VPN.manager.connect(with: configuration)
    }

    func disconnect() {
        isConnecting = false
        configureKillSwitch(enabled: false)
        vpnManager.saveToPreferences()
        vpnManager.connection.stopVPNTunnel()
    }
}
