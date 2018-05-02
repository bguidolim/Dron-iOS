//
//  String+Extensions.swift
//  Dron
//
//  Created by Bruno Guidolim on 29.04.18.
//  Copyright © 2018 Bruno Guidolim. All rights reserved.
//

import Foundation

extension String {
    func localized(_ comment: String = "") -> String {
        return NSLocalizedString(self, comment: comment)
    }
}
