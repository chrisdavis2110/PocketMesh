// PocketMesh/Views/Tools/WardriveView.swift
import SwiftUI
import PocketMeshServices

struct WardriveView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = WardriveViewModel()
    @State private var backendURLText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingCoverageMap = false
    @State private var showingRepeaterIDSheet = false
    @State private var repeaterIDText = ""

    var body: some View {
        Group {
            if appState.services == nil {
                disconnectedState
            } else {
                mainContent
            }
        }
        .navigationTitle("Wardrive")
        .toolbar {
            toolbarContent
        }
        .task(id: appState.servicesVersion) {
            await configureViewModel()
        }
        .onAppear {
            // Load backend URL into text field
            backendURLText = viewModel.backendURL ?? ""
        }
        .onChange(of: viewModel.backendURL) { _, newValue in
            // Sync text field when view model URL changes (but only if different to avoid loops)
            let newText = newValue ?? ""
            if backendURLText != newText {
                backendURLText = newText
            }
        }
        .onDisappear {
            // Save URL when leaving the view
            saveBackendURL()
        }
        .onChange(of: appState.messageEventBroadcaster.newMessageCount) { _, _ in
            // Check for wardrive channel messages to mark pings as heard
            checkForHeardPings()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingCoverageMap) {
            if let backendURL = viewModel.backendURL, !backendURL.isEmpty {
                CoverageMapView(backendURL: backendURL, samples: viewModel.samples)
            }
        }
    }

    private var mainContent: some View {
        List {
            settingsSection
            buttonSection
            intervalSettingsSection
            ignoredRepeaterSection

            if viewModel.samples.isEmpty {
                Section {
                    emptyStateContent
                }
            } else {
                Section {
                    ForEach(viewModel.samples) { sample in
                        WardriveSampleRow(sample: sample)
                    }
                } header: {
                    statusHeader
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var settingsSection: some View {
        Section {
            TextField("Coverage URL", text: $backendURLText)
                .textContentType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)
                .onSubmit {
                    saveBackendURL()
                }
                .onChange(of: backendURLText) { oldValue, newValue in
                    // Save when user finishes editing (debounced)
                    // We'll save on submit or when the view disappears
                }
        } footer: {
            Text("A URL is required to wardrive (e.g., https://coverage.wcmesh.com)")
        }
    }

    private var buttonSection: some View {
            HStack(spacing: 12) {
                let isDisabled = backendURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.services == nil

                Button {
                    Task {
                        await viewModel.sendManualPing()
                    }
                } label: {
                    Text("Manual Ping")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.6) : .white)
                }
                .buttonStyle(.bordered)
                .background(isDisabled ? Color.blue.opacity(0.3) : Color.blue)
                .cornerRadius(8)
                .disabled(isDisabled)

                Button {
                    Task {
                        do {
                            try await viewModel.setAutoPingEnabled(!viewModel.isAutoPingEnabled)
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                } label: {
                    Text(!viewModel.isAutoPingEnabled ? "Start Auto Ping" : "Stop Auto Ping")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(isDisabled ? Color.secondary.opacity(0.6) : .white)
                }
                .buttonStyle(.bordered)
                .background(!viewModel.isAutoPingEnabled ? Color.green : Color.red)
                .cornerRadius(8)
                .disabled(isDisabled)
            }
    }

    private var intervalSettingsSection: some View {
        VStack {
            HStack {
                //                Text("Ping Interval")
                //                    .frame(maxWidth: .infinity, alignment: .leading)
                //
                Picker("Ping Interval", selection: Binding(
                    get: { viewModel.pingIntervalSeconds },
                    set: { viewModel.updatePingInterval($0) }
                )) {
                    Text("Every 30 seconds").tag(30.0)
                    Text("Every 1 minute").tag(60.0)
                    Text("Every 5 minutes").tag(300.0)
                    Text("Every 10 minutes").tag(600.0)
                    Text("Every 30 minutes").tag(1800.0)
                }
                .pickerStyle(.menu)
            }
            
            HStack {
                //                Text("Min Distance")
                //                    .frame(maxWidth: .infinity, alignment: .leading)
                //
                Picker("Min Distance", selection: Binding(
                    get: { viewModel.minDistanceMeters },
                    set: { viewModel.updateMinDistance($0) }
                )) {
                    Text("100 meters").tag(100.0)
                    Text("500 meters").tag(500.0)
                    Text("1 km").tag(1000.0)
                    Text("1 mile").tag(1609.34)
                    Text("5 miles").tag(8046.72)
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var ignoredRepeaterSection: some View {
        //            Text("If you're using a mobile repeater, ignore its id.")
        //                .font(.caption)
        //                .foregroundStyle(.secondary)
        //                .italic()
        
        HStack {
            Text("Ignored Repeater Id")
                .fontWeight(.medium)
            
            Spacer()
            
            Text(" \(viewModel.ignoredRepeaterID ?? "<none>")")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button("Set") {
                repeaterIDText = viewModel.ignoredRepeaterID ?? ""
                showingRepeaterIDSheet = true
            }
            .buttonStyle(.bordered)
        }
        
        .sheet(isPresented: $showingRepeaterIDSheet) {
            ignoredRepeaterIDSheet
        }
    }

    private var ignoredRepeaterIDSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Repeater ID", text: $repeaterIDText)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                } header: {
                    Text("Repeater ID")
                } footer: {
                    Text("Enter a 2-character hex repeater ID to ignore (e.g., \"a1\"). Leave empty to clear.")
                }
            }
            .navigationTitle("Ignored Repeater")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingRepeaterIDSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveIgnoredRepeaterID()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - States

    private var disconnectedState: some View {
        ContentUnavailableView {
            Label("Not Connected", systemImage: "antenna.radiowaves.left.and.right.slash")
        } description: {
            Text("Connect to a mesh radio to use wardriving.")
        }
    }


    private var emptyStateContent: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Samples Yet")
                    .font(.headline)
                Text("Use Manual Ping or enable Auto Ping to start collecting coverage samples.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.vertical, 40)
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusPill

                Text("\(viewModel.samples.count) samples")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let backendURL = viewModel.backendURL, !backendURL.isEmpty {
                    Button {
                        showingCoverageMap = true
                    } label: {
                        Label("View Coverage Map", systemImage: "map")
                            .font(.subheadline)
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.isSendingPing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Sending ping...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.isRunning {
                Text("Pinging...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .modifier(GlassContainerModifier())
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isRunning ? .green : .gray)
                .frame(width: 8, height: 8)

            Text(viewModel.isRunning ? "Active" : "Paused")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .modifier(GlassEffectModifier())
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let backendURL = viewModel.backendURL, !backendURL.isEmpty {
                    Button {
                        showingCoverageMap = true
                    } label: {
                        Label("View Coverage Map", systemImage: "map")
                    }

                    Divider()
                }

                Button(role: .destructive) {
                    viewModel.clearLog()
                } label: {
                    Label("Clear Log", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    // MARK: - Helpers

    private func configureViewModel() async {
        guard let services = appState.services,
              let deviceID = appState.connectedDevice?.id else {
            return
        }

        await viewModel.configure(
            messageService: services.messageService,
            channelService: services.channelService,
            locationService: appState.locationService,
            messagePollingService: services.messagePollingService,
            deviceID: deviceID
        )

        // Load backend URL into text field
        backendURLText = viewModel.backendURL ?? ""
    }

    private func saveBackendURL() {
        Task {
            let trimmedURL = backendURLText.trimmingCharacters(in: .whitespacesAndNewlines)

            // If empty, just clear it
            if trimmedURL.isEmpty {
                await viewModel.updateBackendURL("")
                return
            }

            // Validate and save URL
            await viewModel.updateBackendURL(trimmedURL)

            // Mark setup as complete if we have a URL
            if !trimmedURL.isEmpty {
                UserDefaults.standard.set(true, forKey: "wardriveHasCompletedSetup")
            }
        }
    }

    private func saveIgnoredRepeaterID() {
        let trimmed = repeaterIDText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Validate format (2-character hex)
        if !trimmed.isEmpty {
            // Check if it's valid hex and 2 characters
            let hexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            guard trimmed.count == 2,
                  trimmed.unicodeScalars.allSatisfy({ hexChars.contains($0) }) else {
                errorMessage = "Repeater ID must be a 2-character hex value (e.g., \"a1\")"
                showingError = true
                return
            }
        }

        viewModel.updateIgnoredRepeaterID(trimmed.isEmpty ? nil : trimmed)
        showingRepeaterIDSheet = false
    }

    private func checkForHeardPings() {
        // Check if the latest event is a wardrive channel message
        switch appState.messageEventBroadcaster.latestEvent {
        case .channelMessageReceived(let message, let channelIndex):
            // Check if this is from the wardrive channel
            Task {
                guard let deviceID = appState.connectedDevice?.id,
                      let channelService = appState.services?.channelService else {
                    return
                }

                if let channel = try? await channelService.getChannel(deviceID: deviceID, index: channelIndex),
                   channel.name.localizedCaseInsensitiveCompare("#wardrive") == .orderedSame {
                    // Parse the message to extract location
                    let parts = message.text.split(separator: " ")
                    if parts.count >= 2,
                       let lat = Double(parts[0]),
                       let lon = Double(parts[1]) {
                        await viewModel.markPingAsHeard(latitude: lat, longitude: lon)
                    }
                }
            }
        default:
            break
        }
    }

}

// MARK: - Sample Row

struct WardriveSampleRow: View {
    let sample: WardriveSample

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // First line: Time and status
            HStack {
                Text(sample.timestamp, format: .dateTime.hour().minute().second())
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Spacer()

                statusIcons
            }

            // Second line: Location
            HStack {
                Text("\(sample.latitude, specifier: "%.4f"), \(sample.longitude, specifier: "%.4f")")
                    .font(.caption.monospaced())
                    .foregroundStyle(.primary)
            }

            // Third line: Notes if present
            if let notes = sample.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusIcons: some View {
        HStack(spacing: 4) {
            // Mesh send status
            Image(systemName: sample.sentToMesh ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(sample.sentToMesh ? .green : .red)
                .font(.caption)

            // Backend send status
            Image(systemName: sample.sentToBackend ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(sample.sentToBackend ? .green : .red)
                .font(.caption)

            // Heard status
            Image(systemName: sample.heard ? "ear.fill" : "ear")
                .foregroundStyle(sample.heard ? .blue : .secondary)
                .font(.caption)
        }
    }
}

// MARK: - Glass Effect Modifiers

private struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content
        }
    }
}

private struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect()
        } else {
            content.background(.ultraThinMaterial, in: .capsule)
        }
    }
}

private struct GlassContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer { content }
        } else {
            content
        }
    }
}

#Preview {
    let appState = AppState()

    return NavigationStack {
        WardriveView()
    }
    .environment(\.appState, appState)
    .task {
        // Simulate connected state for preview
        try? await appState.connectionManager.simulatorConnect()
    }
}
