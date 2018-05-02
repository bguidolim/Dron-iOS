//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import RxSwift
import NetworkExtension

class SettingsInteractor: SettingsInteractorInputProtocol {

    weak var presenter: SettingsInteractorOutputProtocol?
    var apiDataManager: SettingsAPIDataManagerInputProtocol?
    var localDatamanager: SettingsLocalDataManagerInputProtocol?

    var disposeBag = DisposeBag()

    init() {
        NotificationCenter.default.rx.notification(Notification.Name.NEVPNStatusDidChange)
            .subscribe(onNext: { [weak self] notification in
                guard let obj = notification.object as? NEVPNConnection else {
                    return
                }
                self?.presenter?.connectionStatusReceived(obj.status)
            }).disposed(by: disposeBag)
    }

    func getCurrentSettings() -> SettingsItem {
        return localDatamanager?.getSettings() ?? SettingsItem()
    }

    func getCountries() {
        if let countries = localDatamanager?.getCountries() {
            self.presenter?.countryListReceived(countries)
            return
        }

        apiDataManager?.getServers().subscribe(onNext: { servers in
            let array = servers.compactMap({ Country(flag: $0.flag, country: $0.country) })
            let countries = Array(Set<Country>(array)).sorted(by: { (obj1, obj2) -> Bool in
                return obj1.country < obj2.country
            })

            self.localDatamanager?.saveCountries(countries)
            DispatchQueue.main.async {
                self.presenter?.countryListReceived(countries)
            }
        }, onError: { error in
            // TODO
            print(error.localizedDescription)
        }).disposed(by: disposeBag)
    }

    func getVPNCurrentStatus() -> NEVPNStatus {
        return VPN.manager.status
    }

    func connectVPN(_ settings: SettingsItem) {
        guard let country = settings.country else {
            return
        }
        localDatamanager?.saveSettings(settings)
        apiDataManager?.getServers().subscribe(onNext: { servers in
            if let bestServer = servers.filter({ $0.country == country }).sorted(by: { (obj1, obj2) -> Bool in
                return obj1.load < obj2.load
            }).first {
                VPN.manager.connectToBestServer(bestServer,
                                                backgroundAction: false)
            }
        }).disposed(by: disposeBag)
    }

    func disconnectVPN() {
        VPN.manager.disconnect()
    }
}
