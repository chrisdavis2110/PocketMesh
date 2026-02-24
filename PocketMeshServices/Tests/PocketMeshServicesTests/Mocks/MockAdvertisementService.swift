import Foundation
import MeshCore
@testable import PocketMeshServices

/// Mock implementation of AdvertisementService for testing handler wiring.
///
/// Captures handlers set via the setter methods, allowing tests to invoke
/// them directly with test data.
public actor MockAdvertisementService {

    // MARK: - Captured Handlers

    public private(set) var capturedAdvertHandler: (@Sendable (ContactFrame) -> Void)?
    public private(set) var capturedPathUpdateHandler: (@Sendable (Data, Int8) -> Void)?
    public private(set) var capturedPathDiscoveryHandler: (@Sendable (PathInfo) -> Void)?
    public private(set) var capturedRoutingChangedHandler: (@Sendable (UUID, Bool) async -> Void)?
    public private(set) var capturedContactUpdatedHandler: (@Sendable () async -> Void)?
    public private(set) var capturedNewContactDiscoveredHandler: (@Sendable (String, UUID, ContactType) async -> Void)?
    public private(set) var capturedContactSyncRequestHandler: (@Sendable (UUID) async -> Void)?
    public private(set) var capturedNodeStorageFullChangedHandler: (@Sendable (Bool) async -> Void)?
    public private(set) var capturedContactDeletedCleanupHandler: (@Sendable (UUID, Data) async -> Void)?

    // MARK: - Initialization

    public init() {}

    // MARK: - Handler Setter Methods (matching AdvertisementService)

    public func setAdvertHandler(_ handler: @escaping @Sendable (ContactFrame) -> Void) {
        capturedAdvertHandler = handler
    }

    public func setPathUpdateHandler(_ handler: @escaping @Sendable (Data, Int8) -> Void) {
        capturedPathUpdateHandler = handler
    }

    public func setPathDiscoveryHandler(_ handler: @escaping @Sendable (PathInfo) -> Void) {
        capturedPathDiscoveryHandler = handler
    }

    public func setRoutingChangedHandler(_ handler: @escaping @Sendable (UUID, Bool) async -> Void) {
        capturedRoutingChangedHandler = handler
    }

    public func setContactUpdatedHandler(_ handler: @escaping @Sendable () async -> Void) {
        capturedContactUpdatedHandler = handler
    }

    public func setNewContactDiscoveredHandler(_ handler: @escaping @Sendable (String, UUID, ContactType) async -> Void) {
        capturedNewContactDiscoveredHandler = handler
    }

    public func setContactSyncRequestHandler(_ handler: @escaping @Sendable (UUID) async -> Void) {
        capturedContactSyncRequestHandler = handler
    }

    public func setNodeStorageFullChangedHandler(_ handler: @escaping @Sendable (Bool) async -> Void) {
        capturedNodeStorageFullChangedHandler = handler
    }

    public func setContactDeletedCleanupHandler(_ handler: @escaping @Sendable (UUID, Data) async -> Void) {
        capturedContactDeletedCleanupHandler = handler
    }

    // MARK: - Test Helpers

    /// Resets all captured handlers
    public func reset() {
        capturedAdvertHandler = nil
        capturedPathUpdateHandler = nil
        capturedPathDiscoveryHandler = nil
        capturedRoutingChangedHandler = nil
        capturedContactUpdatedHandler = nil
        capturedNewContactDiscoveredHandler = nil
        capturedContactSyncRequestHandler = nil
        capturedNodeStorageFullChangedHandler = nil
        capturedContactDeletedCleanupHandler = nil
    }
}
