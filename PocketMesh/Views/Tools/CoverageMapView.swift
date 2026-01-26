// PocketMesh/Views/Tools/CoverageMapView.swift
import SwiftUI
import MapKit
import PocketMeshServices

struct CoverageMapView: View {
    let backendURL: String
    let samples: [WardriveSample]
    @State private var viewModel = CoverageMapViewModel()
    @State private var selectedTile: CoverageTile?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.coverageTiles.isEmpty {
                    ProgressView("Loading coverage data...")
                } else {
                    mapView
                }
            }
            .navigationTitle("Coverage Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.loadCoverageData(backendURL: backendURL)
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                viewModel.setSamples(samples)
                await viewModel.loadCoverageData(backendURL: backendURL)
            }
            .sheet(item: $selectedTile) { tile in
                CoverageTileDetailSheet(tile: tile)
            }
        }
    }

    private var mapView: some View {
        MapReader { proxy in
            Map {
                // Show coverage tiles as rectangles
                ForEach(viewModel.coverageTiles, id: \.geohash) { tile in
                    MapPolygon(coordinates: tile.corners)
                        .foregroundStyle(tile.color.opacity(0.5))
                        .stroke(tile.color, lineWidth: 1)
                }

                // Show user's samples
                ForEach(viewModel.samples) { sample in
                    Annotation(
                        "",
                        coordinate: CLLocationCoordinate2D(
                            latitude: sample.latitude,
                            longitude: sample.longitude
                        )
                    ) {
                        Circle()
                            .fill(sample.heard ? .green : (sample.sentToMesh ? .blue : .red))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 1)
                            )
                    }
                }

                // Show user location if available
                if appState.locationService.currentLocation != nil {
                    UserAnnotation()
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onTapGesture { location in
                // Convert tap location to coordinate
                if let coordinate = proxy.convert(location, from: .local) {
                    // Find which tile contains this coordinate
                    if let tappedTile = viewModel.findTile(containing: coordinate) {
                        selectedTile = tappedTile
                    }
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class CoverageMapViewModel {
    var coverageTiles: [CoverageTile] = []
    var samples: [WardriveSample] = []
    var isLoading = false
    var errorMessage: String?

    func loadCoverageData(backendURL: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch coverage tiles from backend
            let tiles = try await fetchCoverageTiles(backendURL: backendURL)
            coverageTiles = tiles
        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load coverage data: \(error)")
        }

        isLoading = false
    }

    private func fetchCoverageTiles(backendURL: String) async throws -> [CoverageTile] {
        guard let baseURL = URL(string: backendURL) ?? URL(string: "https://\(backendURL)") else {
            throw CoverageMapError.invalidURL
        }

        // Use /get-samples endpoint
        var requestURL = baseURL.appendingPathComponent("get-samples")
        if requestURL.scheme == nil {
            requestURL = URL(string: "https://\(backendURL)/get-samples") ?? requestURL
        }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 10.0

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CoverageMapError.requestFailed
        }

        // Parse JSON response with keys array
        struct SamplesResponse: Codable {
            let keys: [SampleKey]
        }

        struct SampleKey: Codable {
            let name: String // geohash
            let metadata: SampleMetadata?
            // Also support flat format for backward compatibility
            let hash: String?
            let time: Int?
            let path: [String]?
            let observed: Bool?
            let snr: Double?
            let rssi: Int?
        }

        struct SampleMetadata: Codable {
            let time: Int?
            let path: [String]?
            let observed: Bool?
            let snr: Double?
            let rssi: Int?
        }

        let responseData = try JSONDecoder().decode(SamplesResponse.self, from: data)

        // Aggregate samples by coverage tile (first 6 characters of geohash)
        var tileStats: [String: (heard: Int, lost: Int, repeaters: Set<String>)] = [:]

        for key in responseData.keys {
            let geohash = key.name
            guard geohash.count >= 6 else { continue }

            let tileHash = String(geohash.prefix(6))
            let observed = key.metadata?.observed ?? key.observed ?? false
            let path = key.metadata?.path ?? key.path ?? []

            // Collect unique repeater IDs from path
            var repeaterSet = tileStats[tileHash]?.repeaters ?? Set<String>()
            for repeaterID in path {
                if !repeaterID.isEmpty {
                    // Normalize to 2-char ID for display (take first 2 chars if longer)
                    let displayID = repeaterID.count <= 2 ? repeaterID : String(repeaterID.prefix(2))
                    repeaterSet.insert(displayID.uppercased())
                }
            }

            // If observed is true or path has entries, it was heard; otherwise lost
            if observed || !path.isEmpty {
                var stats = tileStats[tileHash] ?? (0, 0, Set<String>())
                stats.heard += 1
                stats.repeaters = repeaterSet
                tileStats[tileHash] = stats
            } else {
                var stats = tileStats[tileHash] ?? (0, 0, Set<String>())
                stats.lost += 1
                stats.repeaters = repeaterSet
                tileStats[tileHash] = stats
            }
        }

        // Convert to coverage tiles with stats
        return tileStats.compactMap { (geohash, stats) in
            CoverageTile.fromGeohash(
                geohash,
                heardCount: stats.heard,
                lostCount: stats.lost,
                repeaters: Array(stats.repeaters).sorted()
            )
        }
    }

    func setSamples(_ samples: [WardriveSample]) {
        self.samples = samples
    }

    func findTile(containing coordinate: CLLocationCoordinate2D) -> CoverageTile? {
        // Find the tile that contains the tapped coordinate
        return coverageTiles.first { tile in
            // Check if coordinate is within tile bounds
            let minLat = tile.corners.map(\.latitude).min() ?? 0
            let maxLat = tile.corners.map(\.latitude).max() ?? 0
            let minLon = tile.corners.map(\.longitude).min() ?? 0
            let maxLon = tile.corners.map(\.longitude).max() ?? 0

            return coordinate.latitude >= minLat &&
                   coordinate.latitude <= maxLat &&
                   coordinate.longitude >= minLon &&
                   coordinate.longitude <= maxLon
        }
    }
}

// MARK: - Coverage Tile

struct CoverageTile: Hashable, Identifiable {
    let id: String // geohash
    let corners: [CLLocationCoordinate2D]
    let geohash: String
    let heardCount: Int
    let lostCount: Int
    let totalCount: Int
    let repeaters: [String] // Unique repeater IDs found in this tile

    init(corners: [CLLocationCoordinate2D], geohash: String, heardCount: Int, lostCount: Int, totalCount: Int, repeaters: [String] = []) {
        self.corners = corners
        self.geohash = geohash
        self.heardCount = heardCount
        self.lostCount = lostCount
        self.totalCount = totalCount
        self.repeaters = repeaters
        self.id = geohash
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(geohash)
    }

    static func == (lhs: CoverageTile, rhs: CoverageTile) -> Bool {
        lhs.geohash == rhs.geohash
    }

    var heardRatio: Double {
        totalCount > 0 ? Double(heardCount) / Double(totalCount) : 0.0
    }

    var color: Color {
        colorForSuccessRate(heardRatio)
    }

    var centerCoordinate: CLLocationCoordinate2D {
        let avgLat = corners.map(\.latitude).reduce(0, +) / Double(corners.count)
        let avgLon = corners.map(\.longitude).reduce(0, +) / Double(corners.count)
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }

    static func fromGeohash(_ geohash: String, heardCount: Int = 0, lostCount: Int = 0, repeaters: [String] = []) -> CoverageTile? {
        // Decode 6-character geohash to bounding box
        // This is a simplified version - full implementation would use a geohash library
        guard geohash.count == 6 else { return nil }

        let bbox = decodeGeohashBbox(geohash)
        let minLat = bbox[0]
        let minLon = bbox[1]
        let maxLat = bbox[2]
        let maxLon = bbox[3]

        // Create rectangle corners (clockwise order for proper polygon rendering)
        return CoverageTile(
            corners: [
                CLLocationCoordinate2D(latitude: minLat, longitude: minLon), // SW
                CLLocationCoordinate2D(latitude: minLat, longitude: maxLon), // SE
                CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon), // NE
                CLLocationCoordinate2D(latitude: maxLat, longitude: minLon)  // NW
            ],
            geohash: geohash,
            heardCount: heardCount,
            lostCount: lostCount,
            totalCount: heardCount + lostCount,
            repeaters: repeaters
        )
    }

    private static func decodeGeohashBbox(_ geohash: String) -> [Double] {
        // Base32 geohash decoding
        let base32 = "0123456789bcdefghjkmnpqrstuvwxyz"
        var isLon = true
        var maxLat: Double = 90.0
        var minLat: Double = -90.0
        var maxLon: Double = 180.0
        var minLon: Double = -180.0

        for char in geohash.lowercased() {
            guard let index = base32.firstIndex(of: char) else { continue }
            let hashValue = base32.distance(from: base32.startIndex, to: index)

            for bit in (0..<5).reversed() {
                let bitValue = (hashValue >> bit) & 1

                if isLon {
                    let mid = (maxLon + minLon) / 2.0
                    if bitValue == 1 {
                        minLon = mid
                    } else {
                        maxLon = mid
                    }
                } else {
                    let mid = (maxLat + minLat) / 2.0
                    if bitValue == 1 {
                        minLat = mid
                    } else {
                        maxLat = mid
                    }
                }
                isLon.toggle()
            }
        }

        return [minLat, minLon, maxLat, maxLon]
    }
}

// MARK: - Color Palette

private func colorForSuccessRate(_ rate: Double) -> Color {
    let clampedRate = max(0.0, min(1.0, rate))

    // Red-Yellow-Green palette (matching web code)
    if clampedRate == 0 {
        return Color(red: 1.0, green: 0.0, blue: 0.0) // Red #FF0000
    } else if clampedRate <= 0.25 {
        return Color(red: 1.0, green: 0.0, blue: 0.0) // Red #FF0000
    } else if clampedRate <= 0.40 {
        return Color(red: 1.0, green: 0.65, blue: 0.0) // Orange #FFA500
    } else if clampedRate <= 0.70 {
        return Color(red: 1.0, green: 1.0, blue: 0.0) // Yellow #FFFF00
    } else if clampedRate <= 0.85 {
        return Color(red: 0.56, green: 0.93, blue: 0.56) // Light green #90EE90
    } else {
        return Color(red: 0.0, green: 0.39, blue: 0.0) // Dark green #006400
    }
}

// MARK: - Coverage Tile Detail Sheet

struct CoverageTileDetailSheet: View {
    let tile: CoverageTile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Coverage Tile") {
                    LabeledContent("Geohash", value: tile.geohash)
                    LabeledContent("Location") {
                        Text("\(tile.centerCoordinate.latitude, specifier: "%.4f"), \(tile.centerCoordinate.longitude, specifier: "%.4f")")
                    }
                }

                Section("Statistics") {
                    LabeledContent("Total Samples", value: "\(tile.totalCount)")
                    LabeledContent("Heard", value: "\(tile.heardCount)")
                    LabeledContent("Lost", value: "\(tile.lostCount)")
                    LabeledContent("Success Rate") {
                        HStack {
                            Text("\(tile.heardRatio * 100, specifier: "%.1f")%")
                            Spacer()
                            Circle()
                                .fill(tile.color)
                                .frame(width: 20, height: 20)
                        }
                    }
                }

                if !tile.repeaters.isEmpty {
                    Section("Repeaters") {
                        LabeledContent("IDs", value: tile.repeaters.joined(separator: ", "))
                    }
                }

                Section {
                    HStack {
                        Text("Color Legend")
                            .font(.headline)
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        LegendRow(color: Color(red: 1.0, green: 0.0, blue: 0.0), label: "0-25% (Red)")
                        LegendRow(color: Color(red: 1.0, green: 0.65, blue: 0.0), label: "25-40% (Orange)")
                        LegendRow(color: Color(red: 1.0, green: 1.0, blue: 0.0), label: "40-70% (Yellow)")
                        LegendRow(color: Color(red: 0.56, green: 0.93, blue: 0.56), label: "70-85% (Light Green)")
                        LegendRow(color: Color(red: 0.0, green: 0.39, blue: 0.0), label: "85-100% (Dark Green)")
                    }
                }
            }
            .navigationTitle("Coverage Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LegendRow: View {
    let color: Color
    let label: String

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
            Text(label)
                .font(.subheadline)
        }
    }
}

// MARK: - Errors

enum CoverageMapError: LocalizedError {
    case invalidURL
    case requestFailed
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .requestFailed:
            return "Failed to fetch coverage data"
        case .decodeFailed:
            return "Failed to decode coverage data"
        }
    }
}
