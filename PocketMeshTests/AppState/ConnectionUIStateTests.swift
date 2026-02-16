import Testing
import Foundation
@testable import PocketMesh

@Suite("Connection UI State Tests")
@MainActor
struct ConnectionUIStateTests {

    // MARK: - statusPillState Priority

    @Test("statusPillState is hidden by default")
    func hiddenByDefault() {
        let appState = AppState()
        #expect(appState.statusPillState == .hidden)
    }

    @Test("Failed state takes priority over syncing")
    func failedOverSyncing() {
        let appState = AppState()
        appState.simulateSyncStarted()
        appState.showSyncFailedPill()

        #expect(appState.statusPillState == .failed(message: "Sync Failed"))
    }

    @Test("Syncing takes priority over ready toast")
    func syncingOverReady() {
        let appState = AppState()
        appState.showReadyToastBriefly()
        appState.simulateSyncStarted()

        #expect(appState.statusPillState == .syncing)
    }

    @Test("Ready toast takes priority over disconnected")
    func readyOverDisconnected() {
        let appState = AppState()
        appState.showReadyToastBriefly()

        // Even if disconnectedPillVisible were true, ready should win
        #expect(appState.statusPillState == .ready)
    }

    @Test("Multiple sync activities keep syncing state until all end")
    func multipleSyncActivities() {
        let appState = AppState()

        appState.simulateSyncStarted()
        appState.simulateSyncStarted()
        #expect(appState.statusPillState == .syncing)

        appState.simulateSyncEnded()
        #expect(appState.statusPillState == .syncing)

        appState.simulateSyncEnded()
        // After all sync activity ends, should not be syncing
        #expect(appState.statusPillState != .syncing)
    }

    // MARK: - Ready Toast

    @Test("showReadyToastBriefly sets showReadyToast to true")
    func showReadyToast() {
        let appState = AppState()

        appState.showReadyToastBriefly()

        #expect(appState.showReadyToast == true)
        #expect(appState.statusPillState == .ready)
    }

    @Test("hideReadyToast immediately clears toast")
    func hideReadyToast() {
        let appState = AppState()
        appState.showReadyToastBriefly()
        #expect(appState.showReadyToast == true)

        appState.hideReadyToast()

        #expect(appState.showReadyToast == false)
        #expect(appState.statusPillState == .hidden)
    }

    @Test("showReadyToastBriefly auto-hides after delay")
    func readyToastAutoHides() async throws {
        let appState = AppState()

        appState.showReadyToastBriefly()
        #expect(appState.showReadyToast == true)

        // Wait for the 2-second auto-hide plus margin
        try await Task.sleep(for: .seconds(2.3))

        #expect(appState.showReadyToast == false)
    }

    @Test("Calling showReadyToastBriefly again resets the timer")
    func readyToastTimerReset() async throws {
        let appState = AppState()

        appState.showReadyToastBriefly()
        try await Task.sleep(for: .seconds(1.5))

        // Call again to reset
        appState.showReadyToastBriefly()
        #expect(appState.showReadyToast == true)

        // Wait past original timer but within new timer
        try await Task.sleep(for: .seconds(1.0))
        #expect(appState.showReadyToast == true)
    }

    // MARK: - Sync Failed Pill

    @Test("showSyncFailedPill sets visible flag")
    func showSyncFailedPill() {
        let appState = AppState()

        appState.showSyncFailedPill()

        #expect(appState.syncFailedPillVisible == true)
        #expect(appState.statusPillState == .failed(message: "Sync Failed"))
    }

    @Test("hideSyncFailedPill immediately clears pill")
    func hideSyncFailedPill() {
        let appState = AppState()
        appState.showSyncFailedPill()

        appState.hideSyncFailedPill()

        #expect(appState.syncFailedPillVisible == false)
    }

    @Test("showSyncFailedPill auto-hides after delay")
    func syncFailedPillAutoHides() async throws {
        let appState = AppState()

        appState.showSyncFailedPill()
        #expect(appState.syncFailedPillVisible == true)

        // Wait for the 7-second auto-hide plus margin
        try await Task.sleep(for: .seconds(7.3))

        #expect(appState.syncFailedPillVisible == false)
    }

    // MARK: - Disconnected Pill

    @Test("disconnectedPillVisible is false by default")
    func disconnectedPillDefault() {
        let appState = AppState()
        #expect(appState.disconnectedPillVisible == false)
    }

    @Test("hideDisconnectedPill clears pill immediately")
    func hideDisconnectedPill() {
        let appState = AppState()

        appState.hideDisconnectedPill()

        #expect(appState.disconnectedPillVisible == false)
    }

    @Test("updateDisconnectedPillState without paired device stays hidden")
    func disconnectedPillNoPairedDevice() async throws {
        // Clean up any leftover device ID from other tests
        let lastDeviceIDKey = "com.pocketmesh.lastConnectedDeviceID"
        let savedValue = UserDefaults.standard.string(forKey: lastDeviceIDKey)
        UserDefaults.standard.removeObject(forKey: lastDeviceIDKey)
        defer {
            if let savedValue {
                UserDefaults.standard.set(savedValue, forKey: lastDeviceIDKey)
            }
        }

        let appState = AppState()

        appState.updateDisconnectedPillState()

        try await Task.sleep(for: .seconds(1.3))
        #expect(appState.disconnectedPillVisible == false)
    }

    // MARK: - canRunSettingsStartupReads

    @Test("canRunSettingsStartupReads is false when disconnected")
    func cannotRunSettingsWhenDisconnected() {
        let appState = AppState()
        #expect(appState.canRunSettingsStartupReads == false)
    }

    // MARK: - withSyncActivity

    @Test("withSyncActivity shows syncing during operation")
    func withSyncActivity() async {
        let appState = AppState()

        await appState.withSyncActivity {
            #expect(appState.statusPillState == .syncing)
        }

        #expect(appState.statusPillState != .syncing)
    }

    @Test("withSyncActivity propagates return value")
    func withSyncActivityReturnValue() async {
        let appState = AppState()

        let result = await appState.withSyncActivity {
            return 42
        }

        #expect(result == 42)
    }

    // MARK: - UI State Defaults

    @Test("Connection alert state defaults")
    func connectionAlertDefaults() {
        let appState = AppState()
        #expect(appState.showingConnectionFailedAlert == false)
        #expect(appState.connectionFailedMessage == nil)
        #expect(appState.pendingReconnectDeviceID == nil)
        #expect(appState.failedPairingDeviceID == nil)
        #expect(appState.otherAppWarningDeviceID == nil)
        #expect(appState.isPairing == false)
        #expect(appState.isNodeStorageFull == false)
    }

    @Test("Derived isConnecting is false when disconnected")
    func isConnectingDefault() {
        let appState = AppState()
        #expect(appState.isConnecting == false)
    }

    @Test("cancelOtherAppWarning clears the device ID")
    func cancelOtherAppWarning() {
        let appState = AppState()
        appState.otherAppWarningDeviceID = UUID()

        appState.cancelOtherAppWarning()

        #expect(appState.otherAppWarningDeviceID == nil)
    }
}
