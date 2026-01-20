import SwiftUI

/// About and links section
struct AboutSection: View {
    var body: some View {
        Section {
            Link(destination: URL(string: "https://meshcore.co.uk")!) {
                HStack {
                    Label {
                        Text("MeshCore Website")
                    } icon: {
                        Image(systemName: "globe")
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)

            Link(destination: URL(string: "https://meshcore.co.uk/map.html")!) {
                HStack {
                    Label {
                        Text("MeshCore Online Map")
                    } icon: {
                        Image(systemName: "map")
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)

            Link(destination: URL(string: "https://github.com/Avi0n/PocketMesh")!) {
                HStack {
                    Label {
                        Text("GitHub")
                    } icon: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)

            Link(destination: URL(string: "https://github.com/sponsors/Avi0n")!) {
                HStack {
                    Label {
                        Text("Support Me")
                    } icon: {
                        Image(systemName: "heart")
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("About")
        }
    }
}
