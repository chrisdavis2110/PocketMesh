import Testing
import MeshCore
@testable import PocketMeshServices

@Suite("ServiceContainer Wiring Tests")
struct ServiceContainerWiringTests {

    /// Creates a ServiceContainer using the test factory.
    @MainActor
    private func makeContainer() throws -> ServiceContainer {
        let transport = SimulatorMockTransport()
        let session = MeshCoreSession(transport: transport)
        return try ServiceContainer.forTesting(session: session)
    }

    @Test("wireServices establishes all 6 cross-service connections")
    @MainActor
    func wireServicesEstablishesAllConnections() async throws {
        let container = try makeContainer()

        await container.wireServices()

        // 1. messageService → contactService
        let hasContact = await container.messageService.hasContactServiceWired
        #expect(hasContact, "messageService should have contactService wired")

        // 2. contactService → syncCoordinator
        let hasContactSync = await container.contactService.hasSyncCoordinatorWired
        #expect(hasContactSync, "contactService should have syncCoordinator wired")

        // 3. nodeConfigService → syncCoordinator
        let hasNodeSync = await container.nodeConfigService.hasSyncCoordinatorWired
        #expect(hasNodeSync, "nodeConfigService should have syncCoordinator wired")

        // 4. contactService cleanup handler
        let hasCleanup = await container.contactService.hasCleanupHandlerWired
        #expect(hasCleanup, "contactService should have cleanupHandler wired")

        // 5. channelService channel update handler
        let hasChannelUpdate = await container.channelService.hasChannelUpdateHandlerWired
        #expect(hasChannelUpdate, "channelService should have channelUpdateHandler wired")

        // 6. rxLogService → heardRepeatsService
        let hasHeardRepeats = await container.rxLogService.hasHeardRepeatsServiceWired
        #expect(hasHeardRepeats, "rxLogService should have heardRepeatsService wired")
    }

    @Test("wireServices is idempotent")
    @MainActor
    func wireServicesIsIdempotent() async throws {
        let container = try makeContainer()

        await container.wireServices()
        await container.wireServices()

        // Verify connections still intact after second call
        let hasContact = await container.messageService.hasContactServiceWired
        #expect(hasContact, "connections should persist after duplicate wireServices call")
    }

    @Test("services are not wired before wireServices is called")
    @MainActor
    func servicesNotWiredBeforeCall() async throws {
        let container = try makeContainer()

        let hasContact = await container.messageService.hasContactServiceWired
        #expect(!hasContact, "messageService should not have contactService before wiring")

        let hasCleanup = await container.contactService.hasCleanupHandlerWired
        #expect(!hasCleanup, "contactService should not have cleanupHandler before wiring")

        let hasHeardRepeats = await container.rxLogService.hasHeardRepeatsServiceWired
        #expect(!hasHeardRepeats, "rxLogService should not have heardRepeatsService before wiring")
    }
}
