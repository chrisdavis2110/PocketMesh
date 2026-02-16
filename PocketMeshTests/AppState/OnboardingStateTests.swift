import Testing
import Foundation
@testable import PocketMesh

@Suite("Onboarding State Tests")
@MainActor
struct OnboardingStateTests {

    private let onboardingKey = "hasCompletedOnboarding"

    private func cleanupUserDefaults() {
        UserDefaults.standard.removeObject(forKey: onboardingKey)
    }

    // MARK: - completeOnboarding

    @Test("completeOnboarding sets flag to true")
    func completeOnboardingSetsFlag() {
        cleanupUserDefaults()
        defer { cleanupUserDefaults() }

        let appState = AppState()
        appState.hasCompletedOnboarding = false

        appState.completeOnboarding()

        #expect(appState.hasCompletedOnboarding == true)
    }

    @Test("completeOnboarding persists to UserDefaults")
    func completeOnboardingPersists() {
        cleanupUserDefaults()
        defer { cleanupUserDefaults() }

        let appState = AppState()
        appState.hasCompletedOnboarding = false

        appState.completeOnboarding()

        #expect(UserDefaults.standard.bool(forKey: onboardingKey) == true)
    }

    // MARK: - resetOnboarding

    @Test("resetOnboarding clears flag")
    func resetOnboardingClearsFlag() {
        cleanupUserDefaults()
        defer { cleanupUserDefaults() }

        let appState = AppState()
        appState.hasCompletedOnboarding = true

        appState.resetOnboarding()

        #expect(appState.hasCompletedOnboarding == false)
    }

    @Test("resetOnboarding clears onboarding path")
    func resetOnboardingClearsPath() {
        cleanupUserDefaults()
        defer { cleanupUserDefaults() }

        let appState = AppState()
        appState.onboardingPath = [.welcome, .permissions]

        appState.resetOnboarding()

        #expect(appState.onboardingPath.isEmpty)
    }

    @Test("resetOnboarding persists false to UserDefaults")
    func resetOnboardingPersists() {
        cleanupUserDefaults()
        defer { cleanupUserDefaults() }

        let appState = AppState()
        appState.hasCompletedOnboarding = true
        appState.resetOnboarding()

        #expect(UserDefaults.standard.bool(forKey: onboardingKey) == false)
    }

    // MARK: - onboardingPath

    @Test("onboardingPath starts empty")
    func onboardingPathDefault() {
        let appState = AppState()
        #expect(appState.onboardingPath.isEmpty)
    }

    @Test("onboardingPath can be appended to")
    func onboardingPathAppend() {
        let appState = AppState()

        appState.onboardingPath.append(.welcome)
        appState.onboardingPath.append(.permissions)

        #expect(appState.onboardingPath == [.welcome, .permissions])
    }

    // MARK: - donateFloodAdvertTipIfOnValidTab

    @Test("donateFloodAdvertTipIfOnValidTab on Chats tab clears pending")
    func donateOnChatsTab() async {
        let appState = AppState()
        appState.selectedTab = 0
        appState.pendingFloodAdvertTipDonation = true

        await appState.donateFloodAdvertTipIfOnValidTab()

        #expect(appState.pendingFloodAdvertTipDonation == false)
    }

    @Test("donateFloodAdvertTipIfOnValidTab on Contacts tab clears pending")
    func donateOnContactsTab() async {
        let appState = AppState()
        appState.selectedTab = 1
        appState.pendingFloodAdvertTipDonation = true

        await appState.donateFloodAdvertTipIfOnValidTab()

        #expect(appState.pendingFloodAdvertTipDonation == false)
    }

    @Test("donateFloodAdvertTipIfOnValidTab on Map tab clears pending")
    func donateOnMapTab() async {
        let appState = AppState()
        appState.selectedTab = 2
        appState.pendingFloodAdvertTipDonation = true

        await appState.donateFloodAdvertTipIfOnValidTab()

        #expect(appState.pendingFloodAdvertTipDonation == false)
    }

    @Test("donateFloodAdvertTipIfOnValidTab on Settings tab sets pending")
    func donateOnSettingsTab() async {
        let appState = AppState()
        appState.selectedTab = 3
        appState.pendingFloodAdvertTipDonation = false

        await appState.donateFloodAdvertTipIfOnValidTab()

        #expect(appState.pendingFloodAdvertTipDonation == true)
    }

    @Test("donateFloodAdvertTipIfOnValidTab on Tools tab sets pending")
    func donateOnToolsTab() async {
        let appState = AppState()
        appState.selectedTab = 4
        appState.pendingFloodAdvertTipDonation = false

        await appState.donateFloodAdvertTipIfOnValidTab()

        #expect(appState.pendingFloodAdvertTipDonation == true)
    }

    // MARK: - hasCompletedOnboarding didSet

    @Test("hasCompletedOnboarding syncs to UserDefaults on set")
    func hasCompletedOnboardingDidSet() {
        cleanupUserDefaults()
        defer { cleanupUserDefaults() }

        let appState = AppState()

        appState.hasCompletedOnboarding = true
        #expect(UserDefaults.standard.bool(forKey: onboardingKey) == true)

        appState.hasCompletedOnboarding = false
        #expect(UserDefaults.standard.bool(forKey: onboardingKey) == false)
    }
}
