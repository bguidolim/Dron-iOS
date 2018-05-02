//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import Default
import RxSwift

private struct CountryList: Codable {
    let countries: [Country]
}

private struct DefaultKeys {
    static let CountryListKey = "CountryList"
    static let SelectedCountryKey = "SelectedCountry"
    static let KillSwitchKey = "KillSwitchEnabled"
}

final class SettingsLocalDataManager: SettingsLocalDataManagerInputProtocol {

    init() {}

    func saveSettings(_ settings: SettingsItem) {
        if let username = settings.username {
            KeychainManager.saveUsername(username)
        }
        if let password = settings.password {
            KeychainManager.savePassword(password)
        }
        if let country = settings.country {
            UserDefaults.standard.set(country, forKey: DefaultKeys.SelectedCountryKey)
        }
        UserDefaults.standard.set(settings.killSwitch, forKey: DefaultKeys.KillSwitchKey)
    }

    func getSettings() -> SettingsItem {
        return SettingsItem(username: KeychainManager.username(),
                            password: KeychainManager.password(),
                            country: UserDefaults.standard.string(forKey: DefaultKeys.SelectedCountryKey),
                            killSwitch: UserDefaults.standard.bool(forKey: DefaultKeys.KillSwitchKey)
        )
    }

    func getCountries() -> [Country]? {
        guard let countryList = UserDefaults.standard.df.fetch(forKey: DefaultKeys.CountryListKey,
                                                               type: CountryList.self) else {
            return nil
        }
        return countryList.countries
    }

    func saveCountries(_ countries: [Country]) {
        UserDefaults.standard.df.store(CountryList(countries: countries), forKey: DefaultKeys.CountryListKey)
    }
}
