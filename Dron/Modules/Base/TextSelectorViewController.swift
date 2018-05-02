//
//  TextSelectorViewController.swift
//  Dron
//
//  Created by Bruno Guidolim on 15.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import UIKit
import Former

final class TextSelectorViewContoller: FormViewController {

    var options = [String]() {
        didSet {
            reloadForm()
        }
    }

    var selectedText: String? {
        didSet {
            former.rowFormers.forEach {
                if let labelRow = $0 as? LabelRowFormer<FormLabelCell>, labelRow.text == selectedText {
                    labelRow.cellUpdate({ $0.accessoryType = .checkmark })
                }
            }
        }
    }

    var onSelected: ((String) -> Void)?

    private func reloadForm() {

        let rows = options.map { text -> LabelRowFormer<FormLabelCell> in
            let optionRow = LabelRowFormer<FormLabelCell>()
                .configure { row in
                    row.text = text
                }.onSelected { [weak self] _  in
                    self?.onSelected?(text)
                    self?.navigationController?.popViewController(animated: true)
            }
            return optionRow
        }

        let sectionFormer = SectionFormer(rowFormers: rows)
        former.removeAll().append(sectionFormer: sectionFormer).reload()
    }
}
