//
//  Item.swift
//  Lectoria
//
//  Created by Favio Cuentas on 15/7/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
