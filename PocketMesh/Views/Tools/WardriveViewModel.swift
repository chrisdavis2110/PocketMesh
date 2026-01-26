// PocketMesh/Views/Tools/WardriveViewModel.swift
import Foundation
import CoreLocation
import PocketMeshServices
import MeshCore
import OSLog

/// Represents a single wardrive ping sample
struct WardriveSample: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let sentToMesh: Bool
    let sentToBackend: Bool
    let heard: Bool
    let notes: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        sentToMesh: Bool,
        sentToBackend: Bool,
        heard: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.sentToMesh = sentToMesh
        self.sentToBackend = sentToBackend
        self.heard = heard
        self.notes = notes
    }
}

@MainActor
@Observable
final class WardriveViewModel {
    private let logger = Logger(subsystem: "com.pocketmesh", category: "WardriveViewModel")

    // MARK: - State

    private(set) var samples: [WardriveSample] = []
    private(set) var isEnabled = false
    private(set) var isAutoPingEnabled = false
    private(set) var isRunning = false
    private(set) var isSendingPing = false
    private(set) var backendURL: String?
    private(set) var wardriveChannel: ChannelDTO?
    private(set) var ignoredRepeaterID: String?

    // MARK: - Dependencies

    private var messageService: MessageService?
    private var channelService: ChannelService?
    private var locationService: LocationService?
    private var messagePollingService: MessagePollingService?
    private var deviceID: UUID?

    // MARK: - Internal State

    private var pingTimer: Task<Void, Never>?
    private var lastSampleLocation: CLLocation?
    private var lastSampleTime: Date?
    private var heardPingHashes: Set<String> = []

    // MARK: - Constants

    private static let defaultPingIntervalSeconds: TimeInterval = 60.0 // 1 minute
    private static let defaultMinDistanceMeters: Double = 1609.34 // 1 mile

    // MARK: - Configurable Settings

    var pingIntervalSeconds: TimeInterval = defaultPingIntervalSeconds
    var minDistanceMeters: Double = defaultMinDistanceMeters
    private static let wardriveChannelName = "#wardrive"
    private static let wardriveChannelSecret = Data([
        0x40, 0x76, 0xC3, 0x15, 0xC1, 0xEF, 0x38, 0x5F,
        0xA9, 0x3F, 0x06, 0x60, 0x27, 0x32, 0x0F, 0xE5
    ])

    // MARK: - UserDefaults Keys

    private static let isEnabledKey = "wardriveEnabled"
    private static let backendURLKey = "wardriveBackendURL"
    private static let hasCompletedSetupKey = "wardriveHasCompletedSetup"
    private static let pingIntervalKey = "wardrivePingInterval"
    private static let minDistanceKey = "wardriveMinDistance"
    private static let ignoredRepeaterIDKey = "wardriveIgnoredRepeaterID"

    // MARK: - Initialization

    init() {
        loadSettings()
    }

    // MARK: - Public Methods

    func configure(
        messageService: MessageService?,
        channelService: ChannelService?,
        locationService: LocationService?,
        messagePollingService: MessagePollingService?,
        deviceID: UUID?
    ) async {
        self.messageService = messageService
        self.channelService = channelService
        self.locationService = locationService
        self.messagePollingService = messagePollingService
        self.deviceID = deviceID

        // Reload settings and sync state
        loadSettings()

        // If auto ping is enabled and we have a new URL, restart with new URL
        if isAutoPingEnabled && isRunning {
            // URL might have changed, reload it
            let newURL = UserDefaults.standard.string(forKey: Self.backendURLKey)
            if newURL != backendURL {
                backendURL = newURL
            }
        }

        // Restore auto ping state if it was enabled
        if isAutoPingEnabled {
            do {
                try await setAutoPingEnabled(true)
            } catch {
                logger.error("Failed to restore auto ping: \(error.localizedDescription)")
                isAutoPingEnabled = false
                isEnabled = false
            }
        }
    }

    func setAutoPingEnabled(_ enabled: Bool) async throws {
        // Don't change if already in desired state
        if enabled && isAutoPingEnabled && isRunning {
            return
        }
        if !enabled && !isAutoPingEnabled {
            return
        }

        if enabled {
            // Validate backend URL is set
            guard let backendURL = backendURL, !backendURL.isEmpty else {
                throw WardriveError.missingBackendURL
            }
            isAutoPingEnabled = true
            await enableWardriving()
        } else {
            isAutoPingEnabled = false
            await disableWardriving()
        }
    }

    func sendManualPing() async {
        // Validate backend URL is set
        guard let backendURL = backendURL, !backendURL.isEmpty else {
            logger.warning("Cannot send manual ping: no backend URL")
            return
        }

        // Ensure channel exists
        guard let deviceID = deviceID,
              let channelService = channelService else {
            logger.warning("Cannot send manual ping: missing dependencies")
            return
        }

        // Ensure wardrive channel exists
        if wardriveChannel == nil {
            do {
                wardriveChannel = try await ensureWardriveChannel(
                    deviceID: deviceID,
                    channelService: channelService
                )
            } catch {
                logger.error("Failed to ensure wardrive channel: \(error.localizedDescription)")
                return
            }
        }

        // Send the ping
        await sendPing()
    }

    func clearLog() {
        samples.removeAll()
        heardPingHashes.removeAll()
    }

    // MARK: - Private Methods

    private func loadSettings() {
        let defaults = UserDefaults.standard
        let newEnabled = defaults.bool(forKey: Self.isEnabledKey)
        let newBackendURL = defaults.string(forKey: Self.backendURLKey)

        // Load ping interval (default: 60 seconds / 1 minute)
        if defaults.object(forKey: Self.pingIntervalKey) != nil {
            pingIntervalSeconds = defaults.double(forKey: Self.pingIntervalKey)
        } else {
            pingIntervalSeconds = Self.defaultPingIntervalSeconds
        }

        // Load min distance (default: 1 mile)
        if defaults.object(forKey: Self.minDistanceKey) != nil {
            minDistanceMeters = defaults.double(forKey: Self.minDistanceKey)
        } else {
            minDistanceMeters = Self.defaultMinDistanceMeters
        }

        // Load ignored repeater ID
        ignoredRepeaterID = defaults.string(forKey: Self.ignoredRepeaterIDKey)

        // Only update if changed to avoid loops
        if newEnabled != isEnabled {
            isEnabled = newEnabled
            isAutoPingEnabled = newEnabled  // Sync auto ping with enabled state
        }
        if newBackendURL != backendURL {
            backendURL = newBackendURL
        }
    }

    func updatePingInterval(_ interval: TimeInterval) {
        pingIntervalSeconds = interval
        UserDefaults.standard.set(interval, forKey: Self.pingIntervalKey)
        logger.info("Ping interval updated to \(interval) seconds")
    }

    func updateMinDistance(_ distance: Double) {
        minDistanceMeters = distance
        UserDefaults.standard.set(distance, forKey: Self.minDistanceKey)
        logger.info("Min distance updated to \(distance) meters")
    }

    func updateIgnoredRepeaterID(_ id: String?) {
        ignoredRepeaterID = id
        if let id = id {
            UserDefaults.standard.set(id, forKey: Self.ignoredRepeaterIDKey)
            logger.info("Ignored repeater ID set to: \(id)")
        } else {
            UserDefaults.standard.removeObject(forKey: Self.ignoredRepeaterIDKey)
            logger.info("Ignored repeater ID cleared")
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isAutoPingEnabled, forKey: Self.isEnabledKey)
        if let backendURL = backendURL {
            defaults.set(backendURL, forKey: Self.backendURLKey)
        }
    }

    private func enableWardriving() async {
        guard let deviceID = deviceID,
              let channelService = channelService,
              let messageService = messageService,
              let locationService = locationService,
              let messagePollingService = messagePollingService else {
            logger.error("Cannot enable wardriving: missing dependencies")
            return
        }

        // Backend URL is required
        guard let backendURL = backendURL, !backendURL.isEmpty else {
            logger.error("Cannot enable wardriving: backend URL is required")
            return
        }

        // Ensure wardrive channel exists
        do {
            wardriveChannel = try await ensureWardriveChannel(
                deviceID: deviceID,
                channelService: channelService
            )

            guard wardriveChannel != nil else {
                logger.error("Failed to create or find wardrive channel")
                return
            }

            // Request location permission
            locationService.requestPermissionIfNeeded()

            // Start pinging
            await startPinging()

            // Note: We don't set up a separate channel message handler to avoid conflicts
            // The "heard" status can be determined by checking if the ping was received
            // by other nodes, but for now we'll just track sent status

            isEnabled = true
            isAutoPingEnabled = true
            saveSettings()
        } catch {
            logger.error("Failed to enable wardriving: \(error.localizedDescription)")
        }
    }

    private func disableWardriving() async {
        pingTimer?.cancel()
        pingTimer = nil

        isRunning = false
        isEnabled = false
        isAutoPingEnabled = false
        saveSettings()
    }

    private func ensureWardriveChannel(
        deviceID: UUID,
        channelService: ChannelService
    ) async throws -> ChannelDTO? {
        // First, try to find existing channel
        let channels = try await channelService.getChannels(deviceID: deviceID)
        if let existing = channels.first(where: { channel in
            channel.name.localizedCaseInsensitiveCompare(Self.wardriveChannelName) == .orderedSame
        }) {
            logger.info("Found existing wardrive channel at index \(existing.index)")
            return existing
        }

        // Find an empty slot
        let emptyIndex = findEmptyChannelSlot(channels: channels)
        guard let index = emptyIndex else {
            logger.error("No empty channel slots available")
            throw WardriveError.noEmptyChannelSlots
        }

        // Create the wardrive channel
        logger.info("Creating wardrive channel at index \(index)")
        try await channelService.setChannelWithSecret(
            deviceID: deviceID,
            index: index,
            name: Self.wardriveChannelName,
            secret: Self.wardriveChannelSecret
        )

        // Fetch the newly created channel
        let updatedChannels = try await channelService.getChannels(deviceID: deviceID)
        return updatedChannels.first(where: { channel in
            channel.name.localizedCaseInsensitiveCompare(Self.wardriveChannelName) == .orderedSame
        })
    }

    private func findEmptyChannelSlot(channels: [ChannelDTO]) -> UInt8? {
        // Find first slot with empty name
        for i in 0..<256 {
            if !channels.contains(where: { $0.index == UInt8(i) && !$0.name.isEmpty }) {
                return UInt8(i)
            }
        }
        return nil
    }

    func updateBackendURL(_ url: String) async {
        // Validate URL
        guard URL(string: url) != nil || URL(string: "https://\(url)") != nil else {
            logger.error("Invalid coverage URL: \(url)")
            return
        }

        self.backendURL = url
        UserDefaults.standard.set(url, forKey: Self.backendURLKey)
        logger.info("Coverage URL updated to: \(url)")
    }

    func reloadBackendURL() {
        let newURL = UserDefaults.standard.string(forKey: Self.backendURLKey)
        if newURL != backendURL {
            backendURL = newURL
            logger.info("Coverage URL reloaded: \(newURL ?? "nil")")
        }
    }

    func markPingAsHeard(latitude: Double, longitude: Double) async {
        let pingHash = "\(latitude),\(longitude)"
        heardPingHashes.insert(pingHash)

        // Update samples that match this location
        for i in samples.indices {
            let sample = samples[i]
            let sampleHash = "\(sample.latitude),\(sample.longitude)"
            // Use approximate matching (within 0.0001 degrees, ~11 meters)
            let latDiff = abs(sample.latitude - latitude)
            let lonDiff = abs(sample.longitude - longitude)
            if latDiff < 0.0001 && lonDiff < 0.0001 && !sample.heard {
                samples[i] = WardriveSample(
                    id: sample.id,
                    timestamp: sample.timestamp,
                    latitude: sample.latitude,
                    longitude: sample.longitude,
                    sentToMesh: sample.sentToMesh,
                    sentToBackend: sample.sentToBackend,
                    heard: true,
                    notes: sample.notes
                )
            }
        }
    }

    private func startPinging() async {
        guard isRunning == false else { return }

        pingTimer?.cancel()
        isRunning = true

        pingTimer = Task { [weak self] in
            guard let self = self else { return }

            // Send initial ping immediately
            await self.sendPing()

            // Then ping on interval
            while !Task.isCancelled && self.isAutoPingEnabled {
                try? await Task.sleep(for: .seconds(self.pingIntervalSeconds))
                if !Task.isCancelled && self.isAutoPingEnabled {
                    await self.sendPing()
                }
            }
        }
    }

    private func sendPing() async {
        guard let deviceID = deviceID,
              let channel = wardriveChannel,
              let messageService = messageService,
              let locationService = locationService else {
            return
        }

        isSendingPing = true

        defer {
            isSendingPing = false
        }

        // Request location update and wait for it
        locationService.requestLocation()

        // Wait a bit for location to update (up to 5 seconds)
        var location: CLLocation?
        for _ in 0..<10 {
            try? await Task.sleep(for: .milliseconds(500))
            location = locationService.currentLocation
            if location != nil {
                break
            }
        }

        guard let location = location else {
            logger.warning("No location available for ping after waiting")
            return
        }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        // Check minimum distance
        if let lastLocation = lastSampleLocation {
            let distance = location.distance(from: lastLocation)
            if distance < minDistanceMeters {
                logger.debug("Skipping ping: distance \(distance)m < minimum \(self.minDistanceMeters)m")
                return
            }
        }

        // Check minimum time
        if let lastTime = lastSampleTime {
            let timeSince = Date().timeIntervalSince(lastTime)
            if timeSince < pingIntervalSeconds {
                logger.debug("Skipping ping: time since last \(timeSince)s < interval \(self.pingIntervalSeconds)s")
                return
            }
        }

        // Format ping message: "<lat> <lon>"
        let pingText = String(format: "%.4f %.4f", lat, lon)
        let pingHash = "\(lat),\(lon)"

        var sentToMesh = false
        var sentToBackend = false
        var notes: String?

        // Send to mesh
        do {
            _ = try await messageService.sendChannelMessage(
                text: pingText,
                channelIndex: channel.index,
                deviceID: deviceID
            )
            sentToMesh = true
            logger.info("Sent wardrive ping: \(pingText)")
        } catch {
            logger.error("Failed to send wardrive ping to mesh: \(error.localizedDescription)")
            notes = "Mesh send failed: \(error.localizedDescription)"
        }

        // Send to backend if configured
        if sentToMesh, let backendURL = backendURL, !backendURL.isEmpty {
            do {
                try await sendPingToBackend(lat: lat, lon: lon, url: backendURL)
                sentToBackend = true
                logger.info("Sent wardrive ping to backend")
            } catch {
                logger.error("Failed to send wardrive ping to backend: \(error.localizedDescription)")
                if notes == nil {
                    notes = "Backend send failed: \(error.localizedDescription)"
                } else {
                    notes = "\(notes!); Backend send failed: \(error.localizedDescription)"
                }
            }
        }

        // Note: "Heard" status would require listening for channel messages
        // For now, we'll set it to false (ping was sent but we don't track if others heard it)
        let heard = false

        // Create sample
        let sample = WardriveSample(
            timestamp: Date(),
            latitude: lat,
            longitude: lon,
            sentToMesh: sentToMesh,
            sentToBackend: sentToBackend,
            heard: heard,
            notes: notes
        )

        samples.insert(sample, at: 0) // Newest first

        // Keep only last 100 samples
        if samples.count > 100 {
            samples.removeLast()
        }

        // Update last sample info
        lastSampleLocation = location
        lastSampleTime = Date()
    }

    private func sendPingToBackend(lat: Double, lon: Double, url: String) async throws {
        // Normalize URL - add scheme if missing
        let normalizedURL: String
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            normalizedURL = url
        } else {
            normalizedURL = "https://\(url)"
        }

        // Remove trailing slash if present
        let cleanURL = normalizedURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Construct full URL with endpoint
        guard let baseURL = URL(string: cleanURL) else {
            logger.error("Invalid backend URL: \(url)")
            throw WardriveError.invalidBackendURL
        }

        let requestURL = baseURL.appendingPathComponent("put-sample")

        let body: [String: Any] = ["lat": lat, "lon": lon]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 10.0

        logger.info("Sending ping to backend: \(requestURL.absoluteString)")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response from backend")
            throw WardriveError.backendRequestFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("Backend returned status code: \(httpResponse.statusCode)")
            throw WardriveError.backendRequestFailed
        }

        logger.info("Successfully sent ping to backend")
    }

    // MARK: - Setup Methods

    func completeSetup(backendURL: String) async throws {
        guard let deviceID = deviceID,
              let channelService = channelService else {
            throw WardriveError.missingDependencies
        }

        // Validate URL
        guard URL(string: backendURL) != nil || URL(string: "https://\(backendURL)") != nil else {
            throw WardriveError.invalidBackendURL
        }

        // Store backend URL
        self.backendURL = backendURL
        UserDefaults.standard.set(backendURL, forKey: Self.backendURLKey)
        UserDefaults.standard.set(true, forKey: Self.hasCompletedSetupKey)

        // Ensure wardrive channel exists
        wardriveChannel = try await ensureWardriveChannel(
            deviceID: deviceID,
            channelService: channelService
        )

        guard wardriveChannel != nil else {
            throw WardriveError.failedToCreateChannel
        }

        // Now enable wardriving
        await enableWardriving()
    }
}

// MARK: - Errors

enum WardriveError: LocalizedError {
    case missingDependencies
    case invalidBackendURL
    case noEmptyChannelSlots
    case failedToCreateChannel
    case backendRequestFailed
    case missingBackendURL

    var errorDescription: String? {
        switch self {
        case .missingDependencies:
            return "Missing required services"
        case .invalidBackendURL:
            return "Invalid backend URL"
        case .noEmptyChannelSlots:
            return "No empty channel slots available"
        case .failedToCreateChannel:
            return "Failed to create wardrive channel"
        case .backendRequestFailed:
            return "Backend request failed"
        case .missingBackendURL:
            return "Backend URL is required to enable wardriving"
        }
    }
}
