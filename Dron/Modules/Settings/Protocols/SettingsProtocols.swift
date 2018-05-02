//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import NetworkExtension

protocol SettingsViewProtocol: class {
    var presenter: SettingsPresenterProtocol? { get set }

    func showCountryOptions(_ options: [String])
    func setConnectionStatus(text: String, value: Bool)
    func setSelectedCountry(_ country: String)
    func updateView(with item: SettingsItem?)
}

protocol SettingsWireframeProtocol: class {
    static var view: UIViewController? { get set }
}

protocol SettingsPresenterProtocol: class {
    var view: SettingsViewProtocol? { get set }
    var interactor: SettingsInteractorInputProtocol? { get set }
    var wireFrame: SettingsWireframeProtocol? { get set }

    func viewDidLoadEvent()
    func countryRowDidSelect()
    func connectSwitchDidChange(with item: SettingsItem, value: Bool)
}

protocol SettingsInteractorOutputProtocol: class {
    func countryListReceived(_ countries: [Country])
    func connectionStatusReceived(_ status: NEVPNStatus)
}

protocol SettingsInteractorInputProtocol: class {
    var presenter: SettingsInteractorOutputProtocol? { get set }
    var apiDataManager: SettingsAPIDataManagerInputProtocol? { get set }
    var localDatamanager: SettingsLocalDataManagerInputProtocol? { get set }

    func getCurrentSettings() -> SettingsItem
    func getCountries()

    func getVPNCurrentStatus() -> NEVPNStatus
    func connectVPN(_ settings: SettingsItem)
    func disconnectVPN()
}

protocol SettingsAPIDataManagerInputProtocol: class {
    func getServers() -> Observable<[Server]>
}

protocol SettingsLocalDataManagerInputProtocol: class {
    func saveSettings(_ settings: SettingsItem)
    func getSettings() -> SettingsItem

    func getCountries() -> [Country]?
    func saveCountries(_ countries: [Country])
}
