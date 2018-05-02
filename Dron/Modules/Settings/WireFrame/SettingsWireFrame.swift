//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Foundation
import UIKit

class SettingsWireframe: SettingsWireframeProtocol {

    static weak var view: UIViewController?

    class func configureViewController() -> UIViewController? {
        // Generating module components
        let view: SettingsViewProtocol = SettingsView()
        let presenter: SettingsPresenterProtocol & SettingsInteractorOutputProtocol = SettingsPresenter()
        let interactor: SettingsInteractorInputProtocol = SettingsInteractor()
        let apiDataManager: SettingsAPIDataManagerInputProtocol = SettingsAPIDataManager()
        let localDataManager: SettingsLocalDataManagerInputProtocol = SettingsLocalDataManager()
        let wireFrame: SettingsWireframeProtocol = SettingsWireframe()

        // Connecting
        view.presenter = presenter
        presenter.view = view
        presenter.wireFrame = wireFrame
        presenter.interactor = interactor
        interactor.presenter = presenter
        interactor.apiDataManager = apiDataManager
        interactor.localDatamanager = localDataManager

        SettingsWireframe.view = view as? UIViewController

        return view as? UIViewController
    }
}
