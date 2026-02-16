import Testing
import Foundation
import PocketMeshServices
@testable import PocketMesh

@Suite("Navigation State Tests")
@MainActor
struct NavigationStateTests {

    // MARK: - Test Helpers

    private static func makeContact(
        id: UUID = UUID(),
        name: String = "TestContact"
    ) -> ContactDTO {
        ContactDTO(
            id: id,
            deviceID: UUID(),
            publicKey: Data(repeating: 0xAA, count: 32),
            name: name,
            typeRawValue: 0x01,
            flags: 0,
            outPathLength: 0,
            outPath: Data(),
            lastAdvertTimestamp: 0,
            latitude: 0,
            longitude: 0,
            lastModified: 0,
            nickname: nil,
            isBlocked: false,
            isMuted: false,
            isFavorite: false,
            lastMessageDate: nil,
            unreadCount: 0,
            unreadMentionCount: 0,
            ocvPreset: nil,
            customOCVArrayString: nil
        )
    }

    private static func makeChannel(
        id: UUID = UUID(),
        name: String = "TestChannel",
        index: UInt8 = 0
    ) -> ChannelDTO {
        ChannelDTO(
            id: id,
            deviceID: UUID(),
            index: index,
            name: name,
            secret: Data(),
            isEnabled: true,
            lastMessageDate: nil,
            unreadCount: 0,
            unreadMentionCount: 0,
            notificationLevel: .all,
            isFavorite: false
        )
    }

    private static func makeRoomSession(
        id: UUID = UUID(),
        name: String = "TestRoom"
    ) -> RemoteNodeSessionDTO {
        RemoteNodeSessionDTO(
            id: id,
            deviceID: UUID(),
            publicKey: Data(repeating: 0xBB, count: 32),
            name: name,
            role: .roomServer,
            latitude: 0,
            longitude: 0,
            isConnected: false,
            permissionLevel: .readWrite,
            lastConnectedDate: nil,
            lastBatteryMillivolts: nil,
            lastUptimeSeconds: nil,
            lastNoiseFloor: nil,
            unreadCount: 0,
            notificationLevel: .all,
            isFavorite: false,
            lastRxAirtimeSeconds: nil,
            neighborCount: 0,
            lastSyncTimestamp: 0,
            lastMessageDate: nil
        )
    }

    // MARK: - Default State

    @Test("Default navigation state is tab 0 with no pending navigation")
    func defaultState() {
        let appState = AppState()
        #expect(appState.selectedTab == 0)
        #expect(appState.pendingChatContact == nil)
        #expect(appState.pendingChannel == nil)
        #expect(appState.pendingRoomSession == nil)
        #expect(appState.pendingDiscoveryNavigation == false)
        #expect(appState.pendingContactDetail == nil)
        #expect(appState.pendingScrollToMessageID == nil)
        #expect(appState.chatsSelectedRoute == nil)
        #expect(appState.tabBarVisibility == .visible)
    }

    // MARK: - navigateToChat

    @Test("navigateToChat sets contact, route, and tab")
    func navigateToChat() {
        let appState = AppState()
        let contact = Self.makeContact()

        appState.navigateToChat(with: contact)

        #expect(appState.pendingChatContact == contact)
        #expect(appState.chatsSelectedRoute == .direct(contact))
        #expect(appState.selectedTab == 0)
        #expect(appState.tabBarVisibility == .hidden)
        #expect(appState.pendingScrollToMessageID == nil)
    }

    @Test("navigateToChat with scrollToMessageID sets message ID")
    func navigateToChatWithScrollTo() {
        let appState = AppState()
        let contact = Self.makeContact()
        let messageID = UUID()

        appState.navigateToChat(with: contact, scrollToMessageID: messageID)

        #expect(appState.pendingChatContact == contact)
        #expect(appState.pendingScrollToMessageID == messageID)
        #expect(appState.chatsSelectedRoute == .direct(contact))
        #expect(appState.selectedTab == 0)
    }

    @Test("navigateToChat switches to Chats tab from another tab")
    func navigateToChatFromOtherTab() {
        let appState = AppState()
        appState.selectedTab = 3 // Settings tab
        let contact = Self.makeContact()

        appState.navigateToChat(with: contact)

        #expect(appState.selectedTab == 0)
        #expect(appState.pendingChatContact == contact)
    }

    // MARK: - navigateToRoom

    @Test("navigateToRoom sets session, route, and tab")
    func navigateToRoom() {
        let appState = AppState()
        let session = Self.makeRoomSession()

        appState.navigateToRoom(with: session)

        #expect(appState.pendingRoomSession == session)
        #expect(appState.chatsSelectedRoute == .room(session))
        #expect(appState.selectedTab == 0)
        #expect(appState.tabBarVisibility == .hidden)
    }

    // MARK: - navigateToChannel

    @Test("navigateToChannel sets channel, route, and tab")
    func navigateToChannel() {
        let appState = AppState()
        let channel = Self.makeChannel()

        appState.navigateToChannel(with: channel)

        #expect(appState.pendingChannel == channel)
        #expect(appState.chatsSelectedRoute == .channel(channel))
        #expect(appState.selectedTab == 0)
        #expect(appState.tabBarVisibility == .hidden)
        #expect(appState.pendingScrollToMessageID == nil)
    }

    @Test("navigateToChannel with scrollToMessageID sets message ID")
    func navigateToChannelWithScrollTo() {
        let appState = AppState()
        let channel = Self.makeChannel()
        let messageID = UUID()

        appState.navigateToChannel(with: channel, scrollToMessageID: messageID)

        #expect(appState.pendingChannel == channel)
        #expect(appState.pendingScrollToMessageID == messageID)
    }

    // MARK: - navigateToDiscovery

    @Test("navigateToDiscovery sets pending flag and contacts tab")
    func navigateToDiscovery() {
        let appState = AppState()

        appState.navigateToDiscovery()

        #expect(appState.pendingDiscoveryNavigation == true)
        #expect(appState.selectedTab == 1)
    }

    @Test("navigateToDiscovery does not hide tab bar")
    func navigateToDiscoveryTabBarVisible() {
        let appState = AppState()

        appState.navigateToDiscovery()

        #expect(appState.tabBarVisibility == .visible)
    }

    // MARK: - navigateToContacts

    @Test("navigateToContacts switches to contacts tab")
    func navigateToContacts() {
        let appState = AppState()
        appState.selectedTab = 3

        appState.navigateToContacts()

        #expect(appState.selectedTab == 1)
    }

    // MARK: - navigateToContactDetail

    @Test("navigateToContactDetail sets contact and contacts tab")
    func navigateToContactDetail() {
        let appState = AppState()
        let contact = Self.makeContact()

        appState.navigateToContactDetail(contact)

        #expect(appState.pendingContactDetail == contact)
        #expect(appState.selectedTab == 1)
    }

    // MARK: - Clear Methods

    @Test("clearPendingNavigation clears chat contact")
    func clearPendingNavigation() {
        let appState = AppState()
        appState.pendingChatContact = Self.makeContact()

        appState.clearPendingNavigation()

        #expect(appState.pendingChatContact == nil)
    }

    @Test("clearPendingRoomNavigation clears room session")
    func clearPendingRoomNavigation() {
        let appState = AppState()
        appState.pendingRoomSession = Self.makeRoomSession()

        appState.clearPendingRoomNavigation()

        #expect(appState.pendingRoomSession == nil)
    }

    @Test("clearPendingChannelNavigation clears channel")
    func clearPendingChannelNavigation() {
        let appState = AppState()
        appState.pendingChannel = Self.makeChannel()

        appState.clearPendingChannelNavigation()

        #expect(appState.pendingChannel == nil)
    }

    @Test("clearPendingDiscoveryNavigation clears discovery flag")
    func clearPendingDiscoveryNavigation() {
        let appState = AppState()
        appState.pendingDiscoveryNavigation = true

        appState.clearPendingDiscoveryNavigation()

        #expect(appState.pendingDiscoveryNavigation == false)
    }

    @Test("clearPendingScrollToMessage clears message ID")
    func clearPendingScrollToMessage() {
        let appState = AppState()
        appState.pendingScrollToMessageID = UUID()

        appState.clearPendingScrollToMessage()

        #expect(appState.pendingScrollToMessageID == nil)
    }

    @Test("clearPendingContactDetailNavigation clears contact detail")
    func clearPendingContactDetailNavigation() {
        let appState = AppState()
        appState.pendingContactDetail = Self.makeContact()

        appState.clearPendingContactDetailNavigation()

        #expect(appState.pendingContactDetail == nil)
    }

    // MARK: - Cross-Tab Navigation

    @Test("navigateToChat from contacts tab hides tab bar and switches tab")
    func crossTabChatNavigation() {
        let appState = AppState()
        appState.selectedTab = 1  // Contacts tab
        let contact = Self.makeContact()

        appState.navigateToChat(with: contact)

        #expect(appState.tabBarVisibility == .hidden)
        #expect(appState.selectedTab == 0)
        #expect(appState.pendingChatContact == contact)
        #expect(appState.chatsSelectedRoute == .direct(contact))
    }

    @Test("Multiple navigation calls overwrite pending state")
    func multipleNavigations() {
        let appState = AppState()
        let contact1 = Self.makeContact(name: "First")
        let contact2 = Self.makeContact(name: "Second")

        appState.navigateToChat(with: contact1)
        appState.navigateToChat(with: contact2)

        #expect(appState.pendingChatContact == contact2)
        #expect(appState.chatsSelectedRoute == .direct(contact2))
    }

    @Test("Flood advert tip donation is pending by default when false")
    func floodAdvertTipDonationDefault() {
        let appState = AppState()
        #expect(appState.pendingFloodAdvertTipDonation == false)
    }
}
