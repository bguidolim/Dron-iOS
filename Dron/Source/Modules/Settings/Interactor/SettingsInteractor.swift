//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import NetworkExtension

class SettingsInteractor: SettingsInteractorInputProtocol {

    weak var presenter: SettingsInteractorOutputProtocol?
    var apiDataManager: SettingsAPIDataManagerInputProtocol?
    var localDatamanager: SettingsLocalDataManagerInputProtocol?

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.vpnStatusDidChange(_:)),
                                               name: .NEVPNStatusDidChange,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let obj = notification.object as? NEVPNConnection else {
            return
        }
        self.presenter?.connectionStatusReceived(obj.status)
    }

    func getCurrentSettings() -> SettingsItem {
        return localDatamanager?.getSettings() ?? SettingsItem()
    }

    func getCountries() {
        if let countries = localDatamanager?.getCountries() {
            self.presenter?.countryListReceived(countries)
            return
        }

        apiDataManager?.getServers().then { servers in
            let array = servers.compactMap({ Country(flag: $0.flag, country: $0.country) })
            let countries = Array(Set<Country>(array)).sorted(by: { (obj1, obj2) -> Bool in
                return obj1.country < obj2.country
            })

            self.localDatamanager?.saveCountries(countries)
            DispatchQueue.main.async {
                self.presenter?.countryListReceived(countries)
            }
        }.onError { error in
            // TODO
            print(error.localizedDescription)
        }
    }

    func getVPNCurrentStatus() -> NEVPNStatus {
        return VPN.manager.status
    }

    func connectVPN(_ settings: SettingsItem) {
        guard let country = settings.country else {
            return
        }
        VPN.manager.connect(to: country,
                            configureKillSwitch: settings.killSwitch)
            .then { [weak self] _ in
                self?.localDatamanager?.saveSettings(settings)
            }
            .onError { error in
                // TODO
                print(error.localizedDescription)
        }
    }

    func disconnectVPN() {
        _ = VPN.manager.disconnect()
    }
}
