//
//  ShifterWidgetBundle.swift
//  ShifterWidget
//
//  Created by David Guia on 06/12/2025.
//

import WidgetKit
import SwiftUI

@main
struct ShifterWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShifterWidget()
        ShifterWidgetControl()
        ShifterWidgetLiveActivity()
    }
}
