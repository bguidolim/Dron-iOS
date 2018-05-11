//
//  AppDelegate.swift
//  Dron
//
//  Created by Bruno Guidolim on 13.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics.self])

        UIApplication.shared.setMinimumBackgroundFetchInterval(30)

        guard let settingsViewController = SettingsWireframe.configureViewController() else {
            return false
        }

        let navigationController = NavigationController(rootViewController: settingsViewController)

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        return true
    }

//    func application(_ application: UIApplication,
//                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//
//        if VPN.manager.status == .disconnected {
//            completionHandler(.noData)
//            return
//        }
//
//        let currentSettings = SettingsLocalDataManager().getSettings()
//        guard let country = currentSettings.country else {
//            completionHandler(.failed)
//            return
//        }
//
//        VPN.manager.connect(to: debugCountry,
//                            configureKillSwitch: currentSettings.killSwitch)
//            .then { _ in
//                completionHandler(.newData)
//            }
//            .onError { error in
//                if case VPNError.alreadyConnectedToServer = error {
//                    completionHandler(.noData)
//                } else {
//                    completionHandler(.failed)
//                }
//        }
//    }
}
