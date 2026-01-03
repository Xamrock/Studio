import Foundation
import SwiftUI
import Combine

protocol RecordingSessionViewModelProtocol: ObservableObject {
    var bundleID: String { get set }
    var selectedDevice: Device? { get }
    var availableDevices: [Device] { get }
    var isLoadingDevices: Bool { get }
    var isRecording: Bool { get }
    var isTestRunning: Bool { get }
    var connectionStatus: String? { get }
    var capturedScreens: [CapturedScreen] { get set }
    var navigationEdges: [NavigationEdge] { get set }
    var flowGroups: [FlowGroup] { get set }
    var errorMessage: String? { get }
    var isCapturing: Bool { get }
    var isInteracting: Bool { get }
    var skipAppLaunch: Bool { get set }

    var interactionService: InteractionService? { get }

    func loadDevices() async
    func startSession() async
    func stopSession() async
    func captureScreen(name: String) async

    func remoteTap(element: SnapshotElement, sourceScreenId: UUID, screenName: String) async
    func remoteTypeText(_ text: String, in element: SnapshotElement, sourceScreenId: UUID, screenName: String) async
    func remoteDoubleTap(element: SnapshotElement, sourceScreenId: UUID, screenName: String) async
    func remoteLongPress(element: SnapshotElement, duration: Double, sourceScreenId: UUID, screenName: String) async
    func remoteTapAtCoordinate(_ coordinate: CGPoint, sourceScreenId: UUID, screenName: String) async
    func remoteSwipeAtCoordinate(_ coordinate: CGPoint, direction: SwipeDirection, sourceScreenId: UUID, screenName: String) async
    func remoteSwipe(element: SnapshotElement, direction: SwipeDirection, sourceScreenId: UUID, screenName: String) async

    func saveSession(to url: URL) throws
    func loadSession(from url: URL) throws
    func exportToJSON() throws -> URL
}
