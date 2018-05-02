//
//  VPNManager.swift
//  Dron
//
//  Created by Bruno Guidolim on 15.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import NetworkExtension
import RxSwift
import RxCocoa

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
    private let disposeBag = DisposeBag()

    func start() {
        load()
            .subscribe({ [unowned self] _ in
                NotificationCenter.default.rx.notification(Notification.Name.NEVPNStatusDidChange)
                    .subscribe(onNext: { [unowned self] notification in
                        guard let obj = notification.object as? NEVPNConnection else {
                            return
                        }
                        if obj.status == .disconnected {
                            if self.isConnecting {
                                try? obj.startVPNTunnel()
                            }
                        }
                    }).disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
    }

    private func load() -> Observable<Any?> {
        return Observable.create({ observer -> Disposable in
            self.vpnManager.loadFromPreferences(completionHandler: { error in
                if let error = error {
                    observer.on(.error(error))
                } else {
                    observer.on(.next(nil))
                    observer.on(.completed)
                }
            })
            return Disposables.create()
        })
    }

    private func save(_ configuration: NEVPNProtocolIKEv2) -> Observable<Any?> {
        vpnManager.localizedDescription = "Dron"
        vpnManager.isEnabled = true
        vpnManager.isOnDemandEnabled = true

        configuration.useExtendedAuthentication = true
        configuration.disconnectOnSleep = false
        vpnManager.protocolConfiguration = configuration

        return Observable.create({ observer -> Disposable in
            self.vpnManager.saveToPreferences(completionHandler: { error in
                if let error = error {
                    observer.on(.error(error))
                } else {
                    observer.on(.next(nil))
                    observer.on(.completed)
                }
            })
            return Disposables.create()
        })
    }

    private func connect() -> Observable<Any?> {
        return Observable.create({ [weak self] observer -> Disposable in
            do {
                try self?.vpnManager.connection.startVPNTunnel()
                observer.on(.next(nil))
                observer.on(.completed)
            } catch {
                observer.on(.error(error))
            }
            return Disposables.create {
                self?.vpnManager.connection.stopVPNTunnel()
            }
        })
    }

    private func connect(with configuration: NEVPNProtocolIKEv2) {
        isConnecting = true
        save(configuration)
            .flatMap({ [unowned self] _ in
                self.connect()
            })
            .subscribe(onError: { (error) in
                // TODO
                print(error.localizedDescription)
            })
            .disposed(by: disposeBag)
    }

    func connectToBestServer(_ server: Server, backgroundAction: Bool) {
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

        UserDefaults.standard.set(server.domain, forKey: DefaultKeys.CurrentServer)
        VPN.manager.connect(with: configuration)
    }

    func disconnect() {
        isConnecting = false
        vpnManager.connection.stopVPNTunnel()
    }
}
