//
//  Act2votionWidgetLiveActivity.swift
//  Act2votionWidget
//
//  Created by Jun Min Kim on 3/17/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Act2votionWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Act2votionWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Act2votionWidgetAttributes.self) { context in
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

extension Act2votionWidgetAttributes {
    fileprivate static var preview: Act2votionWidgetAttributes {
        Act2votionWidgetAttributes(name: "World")
    }
}

extension Act2votionWidgetAttributes.ContentState {
    fileprivate static var smiley: Act2votionWidgetAttributes.ContentState {
        Act2votionWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Act2votionWidgetAttributes.ContentState {
         Act2votionWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Act2votionWidgetAttributes.preview) {
   Act2votionWidgetLiveActivity()
} contentStates: {
    Act2votionWidgetAttributes.ContentState.smiley
    Act2votionWidgetAttributes.ContentState.starEyes
}
