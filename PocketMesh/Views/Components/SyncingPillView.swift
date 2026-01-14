import SwiftUI
import PocketMeshServices

/// A pill-shaped indicator that appears at the top of the app during sync and connection operations
struct SyncingPillView: View {
    var phase: SyncPhase?
    var connectionState: ConnectionState = .disconnected

    var showsConnectedToast: Bool = false
    var showsDisconnectedWarning: Bool = false
    var onDisconnectedTap: (() -> Void)?

    static func shouldShowConnectedToast(
        phase: SyncPhase?,
        connectionState: ConnectionState,
        showsConnectedToast: Bool,
        showsDisconnectedWarning: Bool
    ) -> Bool {
        guard showsConnectedToast else { return false }
        guard !showsDisconnectedWarning else { return false }
        guard phase == nil else { return false }

        switch connectionState {
        case .connecting, .connected:
            return false
        case .disconnected, .ready:
            return true
        }
    }

    static func displayText(
        phase: SyncPhase?,
        connectionState: ConnectionState,
        showsConnectedToast: Bool,
        showsDisconnectedWarning: Bool
    ) -> String {
        if showsDisconnectedWarning {
            return "Disconnected"
        }

        switch connectionState {
        case .connecting, .connected:
            return "Connecting..."
        case .disconnected, .ready:
            break
        }

        switch phase {
        case .contacts:
            return "Syncing contacts"
        case .channels:
            return "Syncing channels"
        case .messages:
            return "Syncing"
        case nil:
            break
        }

        if shouldShowConnectedToast(
            phase: phase,
            connectionState: connectionState,
            showsConnectedToast: showsConnectedToast,
            showsDisconnectedWarning: showsDisconnectedWarning
        ) {
            return "Connected"
        }

        return "Syncing"
    }

    private var shouldShowConnectedToast: Bool {
        Self.shouldShowConnectedToast(
            phase: phase,
            connectionState: connectionState,
            showsConnectedToast: showsConnectedToast,
            showsDisconnectedWarning: showsDisconnectedWarning
        )
    }

    private var displayText: String {
        Self.displayText(
            phase: phase,
            connectionState: connectionState,
            showsConnectedToast: showsConnectedToast,
            showsDisconnectedWarning: showsDisconnectedWarning
        )
    }

    var body: some View {
        if showsDisconnectedWarning, let onDisconnectedTap {
            Button(action: onDisconnectedTap) {
                pillBody()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Double tap to connect device")
        } else {
            pillBody()
        }
    }

    @ViewBuilder
    private func pillBody() -> some View {
        HStack(spacing: 8) {
            if showsDisconnectedWarning {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if shouldShowConnectedToast {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                ProgressView()
                    .controlSize(.small)
            }

            Text(displayText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(showsDisconnectedWarning ? .orange : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayText)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        VStack(spacing: 12) {
            SyncingPillView(phase: .contacts)
            SyncingPillView(phase: nil, connectionState: .connecting)
            SyncingPillView(showsConnectedToast: true)
            SyncingPillView(showsDisconnectedWarning: true)
            Spacer()
        }
        .padding(.top, 60)
    }
}
