//
// Created by Bruno Guidolim
// Copyright (c) 2018 Bruno Guidolim. All rights reserved.
//

import Former
import RxSwift

final class SettingsView: FormViewController, SettingsViewProtocol {

    var presenter: SettingsPresenterProtocol?

    private let connectRow = SwitchRowFormer<FormSwitchCell>()
    private let usernameRow = TextFieldRowFormer<FormTextFieldCell>()
    private let passwordRow = TextFieldRowFormer<FormTextFieldCell>()
    private let countrySelectorRow = LabelRowFormer<FormLabelCell>()
    private let killSwitchRow = SwitchRowFormer<FormSwitchCell>()

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupConnectSection()
        setupUserSection()
        setupOptionsSection()

        presenter?.viewDidLoadEvent()
    }

    func updateView(with item: SettingsItem?) {
        usernameRow.text = item?.username ?? ""
        passwordRow.text = item?.password ?? ""
        countrySelectorRow.subText = item?.country ?? "settings.country.row.value".localized()
        killSwitchRow.switched = item?.killSwitch ?? false
    }

    func setupConnectSection() {
        connectRow.configure { row in
            row.cell.titleLabel.text = "settings.connect.row.label".localized()
            row.switchWhenSelected = true
            }.onSwitchChanged { [unowned self] value in
                let item = SettingsItem(username: self.usernameRow.text,
                                        password: self.passwordRow.text,
                                        country: self.countrySelectorRow.subText,
                                        killSwitch: self.killSwitchRow.switched)
                self.presenter?.connectSwitchDidChange(with: item, value: value)
        }

        let section = SectionFormer(rowFormers: [connectRow])
        former.append(sectionFormer: section)
    }

    func setupUserSection() {
        usernameRow.configure { row in
            row.cell.titleLabel.text = "settings.username.row.label".localized()
            row.cell.textField.placeholder = "settings.username.row.text.placeholder".localized()
            row.cell.textField.autocapitalizationType = .none
            row.cell.textField.keyboardType = .emailAddress
        }

        passwordRow.configure { row in
            row.cell.titleLabel.text = "settings.password.row.label".localized()
            row.cell.textField.isSecureTextEntry = true
            row.cell.textField.placeholder = "settings.password.row.text.placeholder".localized()
        }

        let section = SectionFormer(rowFormers: [usernameRow, passwordRow])
        former.append(sectionFormer: section)
    }

    func setupOptionsSection() {

        countrySelectorRow.configure { row in
            row.text = "settings.country.row.label".localized()
            }.onSelected {[weak self] row in
                row.cellUpdate({ $0.setSelected(false, animated: true) })
                self?.presenter?.countryRowDidSelect()
        }

        killSwitchRow.configure { row in
            row.cell.titleLabel.text = "settings.killswitch.row.label".localized()
            row.switchWhenSelected = true
        }

        let section = SectionFormer(rowFormers: [countrySelectorRow, killSwitchRow])
        former.append(sectionFormer: section)
    }

    func showCountryOptions(_ options: [String]) {
        let controller = TextSelectorViewContoller()
        controller.options = options
        controller.selectedText = countrySelectorRow.subText
        controller.onSelected = { [weak self] in
            self?.countrySelectorRow.subText = $0
            self?.countrySelectorRow.update()
        }
        self.navigationController?.pushViewController(controller, animated: true)
    }

    func setConnectionStatus(text: String, value: Bool) {
        connectRow.cell.titleLabel.text = text
        connectRow.switched = value
        connectRow.update()
    }

    func setSelectedCountry(_ country: String) {
        countrySelectorRow.subText = country
    }
}
