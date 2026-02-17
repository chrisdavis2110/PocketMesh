import Foundation
import Testing
@testable import PocketMeshServices

struct NotificationStringProviderTests {

    /// Mock implementation for testing
    struct MockStringProvider: NotificationStringProvider {
        func discoveryNotificationTitle(for type: ContactType) -> String {
            switch type {
            case .chat: "Mock Contact Title"
            case .repeater: "Mock Repeater Title"
            case .room: "Mock Room Title"
            }
        }
    }

    @Test("Provider returns correct title for chat type")
    func providerReturnsChatTitle() {
        let provider = MockStringProvider()
        let title = provider.discoveryNotificationTitle(for: .chat)
        #expect(title == "Mock Contact Title")
    }

    @Test("Provider returns correct title for repeater type")
    func providerReturnsRepeaterTitle() {
        let provider = MockStringProvider()
        let title = provider.discoveryNotificationTitle(for: .repeater)
        #expect(title == "Mock Repeater Title")
    }

    @Test("Provider returns correct title for room type")
    func providerReturnsRoomTitle() {
        let provider = MockStringProvider()
        let title = provider.discoveryNotificationTitle(for: .room)
        #expect(title == "Mock Room Title")
    }

    @Test("Default fallback titles are English")
    @MainActor
    func defaultFallbackTitlesAreEnglish() {
        let service = NotificationService()
        #expect(service.defaultDiscoveryTitle(for: .chat) == "New Contact Discovered")
        #expect(service.defaultDiscoveryTitle(for: .repeater) == "New Repeater Discovered")
        #expect(service.defaultDiscoveryTitle(for: .room) == "New Room Discovered")
    }
}
