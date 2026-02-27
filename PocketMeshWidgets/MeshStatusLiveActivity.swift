import ActivityKit
import SwiftUI
import WidgetKit

struct MeshStatusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeshStatusAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color(red: 51 / 255, green: 102 / 255, blue: 136 / 255).opacity(0.4)) // slate blue (#336688)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.state.antennaIconName)
                            .foregroundStyle(context.state.isConnected ? .green : .orange)
                            .accessibilityHidden(true)
                        Text(context.attributes.deviceName)
                            .bold()
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .font(.headline)
                    .accessibilityElement(children: .combine)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isConnected {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("\(context.state.packetsPerMinute)")
                                .font(.title3.bold())
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("/m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("\(context.state.packetsPerMinute) packets per minute")
                    } else {
                        Text("Disconnected")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    BatteryLabel(percent: context.state.batteryPercent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isConnected, context.state.unreadCount > 0 {
                        HStack {
                            Image(systemName: "envelope.badge")
                                .accessibilityHidden(true)
                            Text("\(context.state.unreadCount) unread")
                                .contentTransition(.numericText())
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                    }

                    if !context.state.isConnected, let date = context.state.disconnectedDate {
                        Text(date, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.antennaIconName)
                    .foregroundStyle(context.state.isConnected ? .green : .orange)
            } compactTrailing: {
                if context.state.isConnected {
                    Text("↓\(context.state.packetsPerMinute)/m")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Text("—")
                }
            } minimal: {
                Image(systemName: context.state.antennaIconName)
                    .foregroundStyle(context.state.isConnected ? .green : .orange)
            }
            .widgetURL(URL(string: "pocketmesh://status"))
        }
    }
}
