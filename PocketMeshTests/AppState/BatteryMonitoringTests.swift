import Testing
import Foundation
import MeshCore
import PocketMeshServices
@testable import PocketMesh

@Suite("Battery Monitoring Tests")
@MainActor
struct BatteryMonitoringTests {

    // MARK: - Default State

    @Test("deviceBattery is nil by default")
    func deviceBatteryDefault() {
        let appState = AppState()
        #expect(appState.deviceBattery == nil)
    }

    @Test("activeBatteryOCVArray returns liIon default when no device connected")
    func activeBatteryOCVArrayDefault() {
        let appState = AppState()
        #expect(appState.activeBatteryOCVArray == OCVPreset.liIon.ocvArray)
    }

    // MARK: - fetchDeviceBattery

    @Test("fetchDeviceBattery is no-op when services is nil")
    func fetchDeviceBatteryNoServices() async {
        let appState = AppState()

        await appState.fetchDeviceBattery()

        #expect(appState.deviceBattery == nil)
    }

    @Test("fetchDeviceBattery does not crash when called on fresh state")
    func fetchDeviceBatterySafe() async {
        let appState = AppState()
        #expect(appState.services == nil)

        // Should not throw or crash
        await appState.fetchDeviceBattery()
        #expect(appState.deviceBattery == nil)
    }

    // MARK: - Battery State Observation

    @Test("deviceBattery can be set directly for testing")
    func deviceBatterySettable() {
        let appState = AppState()
        let battery = BatteryInfo(level: 3700)

        appState.deviceBattery = battery

        #expect(appState.deviceBattery == battery)
        #expect(appState.deviceBattery?.level == 3700)
    }

    @Test("deviceBattery can be cleared")
    func deviceBatteryClearable() {
        let appState = AppState()
        appState.deviceBattery = BatteryInfo(level: 3700)

        appState.deviceBattery = nil

        #expect(appState.deviceBattery == nil)
    }
}
