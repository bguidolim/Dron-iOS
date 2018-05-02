//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import NetworkExtension

class SettingsPresenter: SettingsPresenterProtocol, SettingsInteractorOutputProtocol {
    weak var view: SettingsViewProtocol?
    var interactor: SettingsInteractorInputProtocol?
    var wireFrame: SettingsWireframeProtocol?

    init() {}

    func viewDidLoadEvent() {
        connectionStatusReceived((self.interactor?.getVPNCurrentStatus())!)

        let settingsItem = interactor?.getCurrentSettings()
        view?.updateView(with: settingsItem)
    }

    func countryRowDidSelect() {
        interactor?.getCountries()
    }

    func countryListReceived(_ countries: [Country]) {
        let options = countries.compactMap({ $0.country })
        self.view?.showCountryOptions(options)
    }

    func connectionStatusReceived(_ status: NEVPNStatus) {
        switch status {
        case .connected:
            self.view?.setConnectionStatus(text: "vpn.status.connected".localized(), value: true)
        case .connecting, .reasserting:
            self.view?.setConnectionStatus(text: "vpn.status.connecting".localized(), value: true)
        case .disconnected, .invalid:
            self.view?.setConnectionStatus(text: "vpn.status.disconnected".localized(), value: false)
        case .disconnecting:
            self.view?.setConnectionStatus(text: "vpn.status.disconnecting".localized(), value: true)
        }
    }

    func connectSwitchDidChange(with item: SettingsItem, value: Bool) {
        if value {
            interactor?.connectVPN(item)
        } else {
            interactor?.disconnectVPN()
        }
    }
}
