import Foundation
import SwiftUI
import Combine

@MainActor
class RecordingSessionViewModel: ObservableObject, RecordingSessionViewModelProtocol {
    // MARK: - Published Properties
    @Published var capturedScreens: [CapturedScreen] = []
    @Published var navigationEdges: [NavigationEdge] = []
    @Published var flowGroups: [FlowGroup] = []
    @Published var skipAppLaunch = false

    // MARK: - Coordinators & Services
    let deviceManager: DeviceManager
    let sessionCoordinator: SessionCoordinator
    private var snapshotCapturingService: SnapshotCapturingService?
    private var interactionCoordinator: InteractionCoordinator?

    private let bundleIDManager: BundleIDManager
    private let sessionPersistence = SessionPersistenceService()
    private let exportService = SessionExportService()
    private let interactionHandler = InteractionHandler()
    private let flowGroupManager = FlowGroupManager()
    private var cancellables = Set<AnyCancellable>()

    var interactionService: InteractionService? {
        sessionCoordinator.interactionService
    }

    // MARK: - Bundle ID (delegated to BundleIDManager)
    var bundleID: String {
        get { bundleIDManager.bundleID }
        set {
            Task {
                await bundleIDManager.setBundleID(newValue)
            }
        }
    }

    // MARK: - Computed Properties
    var isRecording: Bool { sessionCoordinator.isRecording }
    var isTestRunning: Bool { sessionCoordinator.isTestRunning }
    var errorMessage: String? {
        get {
            sessionCoordinator.errorMessage
            ?? deviceManager.errorMessage
            ?? snapshotCapturingService?.errorMessage
        }
        set {
            sessionCoordinator.errorMessage = newValue
        }
    }
    var isCapturing: Bool { snapshotCapturingService?.isCapturing ?? false }
    var isInteracting: Bool { interactionCoordinator?.isInteracting ?? false }
    var selectedDevice: Device? {
        get { deviceManager.selectedDevice }
        set { deviceManager.selectedDevice = newValue }
    }
    var availableDevices: [Device] { deviceManager.availableDevices }
    var isLoadingDevices: Bool { deviceManager.isLoadingDevices }

    // MARK: - Initialization
    init(
        deviceManager: DeviceManager? = nil,
        sessionCoordinator: SessionCoordinator? = nil,
        bundleIDManager: BundleIDManager? = nil
    ) {
        self.deviceManager = deviceManager ?? DeviceManager()
        self.sessionCoordinator = sessionCoordinator ?? SessionCoordinator()
        self.bundleIDManager = bundleIDManager ?? BundleIDManager()

        self.deviceManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        self.sessionCoordinator.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        self.bundleIDManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    // MARK: - Device Management
    func loadDevices() async {
        do {
            try await deviceManager.loadDevices()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load devices: \(error.localizedDescription)"
        }
    }

    // MARK: - Session Management
    func startSession() async {
        guard let device = deviceManager.selectedDevice else {
            sessionCoordinator.errorMessage = "Please select a device"
            return
        }

        do {
            try await sessionCoordinator.startSession(
                bundleID: bundleIDManager.bundleID,
                device: device,
                skipAppLaunch: skipAppLaunch
            )

            snapshotCapturingService = SnapshotCapturingService(sessionCoordinator: sessionCoordinator)

            if let interactionService = sessionCoordinator.interactionService {
                interactionCoordinator = InteractionCoordinator(interactionService: interactionService)
            }

            await captureScreen(name: "Initial Screen")

        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
        }
    }

    func stopSession() async {
        interactionCoordinator?.cancelOngoingInteractions()

        await sessionCoordinator.stopSession()

        snapshotCapturingService = nil
        interactionCoordinator = nil
    }

    // MARK: - Screen Capture
    func captureScreen(name: String = "Untitled Screen") async {
        guard let snapshotService = snapshotCapturingService else {
            errorMessage = "No active session"
            return
        }

        do {
            let screen = try await snapshotService.captureSnapshot(name: name)
            capturedScreens.append(screen)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to capture screen: \(error.localizedDescription)"
        }
    }

    // MARK: - Interactions (using InteractionHandler)
    func remoteTap(element: SnapshotElement, sourceScreenId: UUID, screenName: String = "") async {
        if let result = await interactionHandler.handleInteraction(
            coordinator: interactionCoordinator,
            errorMessage: "Failed to interact",
            onError: { self.sessionCoordinator.errorMessage = $0 },
            action: { try await $0.tap(element: element, sourceScreenId: sourceScreenId, screenName: screenName) }
        ) {
            capturedScreens.append(result.capturedScreen)
            navigationEdges.append(result.navigationEdge)
        }
    }

    func remoteTypeText(_ text: String, in element: SnapshotElement, sourceScreenId: UUID, screenName: String = "") async {
        if let result = await interactionHandler.handleInteraction(
            coordinator: interactionCoordinator,
            errorMessage: "Failed to type text",
            onError: { self.sessionCoordinator.errorMessage = $0 },
            action: { try await $0.typeText(text, in: element, sourceScreenId: sourceScreenId, screenName: screenName) }
        ) {
            capturedScreens.append(result.capturedScreen)
            navigationEdges.append(result.navigationEdge)
        }
    }

    func remoteDoubleTap(element: SnapshotElement, sourceScreenId: UUID, screenName: String = "") async {
        if let result = await interactionHandler.handleInteraction(
            coordinator: interactionCoordinator,
            errorMessage: "Failed to double-tap",
            onError: { self.sessionCoordinator.errorMessage = $0 },
            action: { try await $0.doubleTap(element: element, sourceScreenId: sourceScreenId, screenName: screenName) }
        ) {
            capturedScreens.append(result.capturedScreen)
            navigationEdges.append(result.navigationEdge)
        }
    }

    func remoteLongPress(element: SnapshotElement, duration: Double, sourceScreenId: UUID, screenName: String = "") async {
        if let result = await interactionHandler.handleInteraction(
            coordinator: interactionCoordinator,
            errorMessage: "Failed to long press",
            onError: { self.sessionCoordinator.errorMessage = $0 },
            action: { try await $0.longPress(element: element, duration: duration, sourceScreenId: sourceScreenId, screenName: screenName) }
        ) {
            capturedScreens.append(result.capturedScreen)
            navigationEdges.append(result.navigationEdge)
        }
    }

    func remoteTapAtCoordinate(_ coordinate: CGPoint, sourceScreenId: UUID, screenName: String = "") async {
        if let result = await interactionHandler.handleInteraction(
            coordinator: interactionCoordinator,
            errorMessage: "Failed to tap coordinate",
            onError: { self.sessionCoordinator.errorMessage = $0 },
            action: { try await $0.tapAtCoordinate(coordinate, sourceScreenId: sourceScreenId, screenName: screenName) }
        ) {
            capturedScreens.append(result.capturedScreen)
            navigationEdges.append(result.navigationEdge)
        }
    }

    func remoteSwipeAtCoordinate(_ coordinate: CGPoint, direction: SwipeDirection, sourceScreenId: UUID, screenName: String = "") async {
        if let result = await interactionHandler.handleInteraction(
            coordinator: interactionCoordinator,
            errorMessage: "Failed to swipe at coordinate",
            onError: { self.sessionCoordinator.errorMessage = $0 },
            action: { try await $0.swipeAtCoordinate(coordinate, direction: direction, sourceScreenId: sourceScreenId, screenName: screenName) }
        ) {
            capturedScreens.append(result.capturedScreen)
            navigationEdges.append(result.navigationEdge)
        }
    }

    func remoteSwipe(element: SnapshotElement, direction: SwipeDirection, sourceScreenId: UUID, screenName: String = "") async {
        if let result = await interactionHandler.handleInteraction(
            coordinator: interactionCoordinator,
            errorMessage: "Failed to swipe",
            onError: { self.sessionCoordinator.errorMessage = $0 },
            action: { try await $0.swipe(element: element, direction: direction, sourceScreenId: sourceScreenId, screenName: screenName) }
        ) {
            capturedScreens.append(result.capturedScreen)
            navigationEdges.append(result.navigationEdge)
        }
    }

    // MARK: - Session Persistence (delegated to SessionPersistenceService)
    func saveSession(to url: URL) throws {
        try sessionPersistence.save(
            bundleID: bundleIDManager.bundleID,
            screens: capturedScreens,
            edges: navigationEdges,
            flowGroups: flowGroups,
            to: url
        )
    }

    func loadSession(from url: URL) throws {
        let session = try sessionPersistence.load(from: url)

        bundleIDManager.updateBundleID(session.bundleID)
        capturedScreens = session.screens
        navigationEdges = session.edges
        flowGroups = session.flowGroups
    }

    func exportToJSON() throws -> URL {
        try exportService.exportSession(
            screens: capturedScreens,
            edges: navigationEdges,
            flowGroups: flowGroups
        )
    }

    // MARK: - FlowGroup Management (delegated to FlowGroupManager)
    func createFlowGroup(name: String, color: FlowGroup.FlowColor, screenIds: Set<UUID> = []) {
        let newGroup = flowGroupManager.createGroup(name: name, color: color, screenIds: screenIds)
        flowGroups.append(newGroup)

        if !screenIds.isEmpty {
            capturedScreens = flowGroupManager.updateGroupAssignments(
                groupId: newGroup.id,
                screenIds: screenIds,
                in: capturedScreens
            )
        }
    }

    func updateFlowGroup(id: UUID, name: String, color: FlowGroup.FlowColor) {
        guard let index = flowGroups.firstIndex(where: { $0.id == id }) else { return }

        let updatedGroup = flowGroupManager.updateGroup(
            flowGroups[index],
            name: name,
            color: color
        )
        flowGroups[index] = updatedGroup
    }

    func deleteFlowGroup(id: UUID) {
        flowGroups.removeAll { $0.id == id }

        capturedScreens = flowGroupManager.deleteGroup(groupId: id, from: capturedScreens)
    }

    func assignScreenToFlowGroup(screenId: UUID, groupId: UUID) {
        capturedScreens = flowGroupManager.assignScreenToGroup(
            screenId: screenId,
            groupId: groupId,
            in: capturedScreens
        )
    }

    func removeScreenFromFlowGroup(screenId: UUID, groupId: UUID) {
        capturedScreens = flowGroupManager.removeScreenFromGroup(
            screenId: screenId,
            groupId: groupId,
            from: capturedScreens
        )
    }

    func updateFlowGroupScreenAssignments(groupId: UUID, screenIds: Set<UUID>) {
        capturedScreens = flowGroupManager.updateGroupAssignments(
            groupId: groupId,
            screenIds: screenIds,
            in: capturedScreens
        )
    }
}
