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
import RxSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let apiClient = NordAPIClient()
    let disposeBag = DisposeBag()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics.self])

        VPN.manager.start()
        UIApplication.shared.setMinimumBackgroundFetchInterval(60)

        guard let settingsViewController = SettingsWireframe.configureViewController() else {
            return false
        }

        let navigationController = NavigationController(rootViewController: settingsViewController)

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        return true
    }

    func application(_ application: UIApplication,
                     performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

        let currentSettings = SettingsLocalDataManager().getSettings()

        guard let currentServer = VPN.manager.currentServer,
            let country = currentSettings.country else {
            completionHandler(.failed)
            return
        }

        Answers.logCustomEvent(withName: "Background Fetch", customAttributes: ["Status": "Started"])

        let serverRequest: Observable<[Server]> = apiClient.request(Server.Resource.getServers)
        serverRequest
            .subscribe(onNext: { (servers) in
            if let server = servers.filter({ $0.country == country }).sorted(by: { (obj1, obj2) -> Bool in
                return obj1.load < obj2.load
            }).first {
                if currentServer == server.domain {
                    Answers.logCustomEvent(withName: "Background Fetch", customAttributes: ["Status": "No Data"])
                    completionHandler(.noData)
                    return
                }

                VPN.manager.connectToBestServer(server, backgroundAction: true)
                Answers.logCustomEvent(withName: "Background Fetch", customAttributes: ["Status": "New Data"])
                completionHandler(.newData)
            }
        }, onError: { _ in
            Answers.logCustomEvent(withName: "Background Fetch", customAttributes: ["Status": "Failed"])
            completionHandler(.failed)
        }).disposed(by: disposeBag)
    }
}
