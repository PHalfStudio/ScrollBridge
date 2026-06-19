//
//  Item.swift
//  MouseBridge
//
//  Created by Natsume on 2026/6/19.
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
