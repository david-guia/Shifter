//
//  ShifterWidgetLiveActivity.swift
//  ShifterWidget
//
//  Created by David Guia on 06/12/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ShifterWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct ShifterWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShifterWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension ShifterWidgetAttributes {
    fileprivate static var preview: ShifterWidgetAttributes {
        ShifterWidgetAttributes(name: "World")
    }
}

extension ShifterWidgetAttributes.ContentState {
    fileprivate static var smiley: ShifterWidgetAttributes.ContentState {
        ShifterWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: ShifterWidgetAttributes.ContentState {
         ShifterWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: ShifterWidgetAttributes.preview) {
   ShifterWidgetLiveActivity()
} contentStates: {
    ShifterWidgetAttributes.ContentState.smiley
    ShifterWidgetAttributes.ContentState.starEyes
}
