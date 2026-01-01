import Testing
import Foundation
@testable import Xamrock_Studio

@MainActor
struct SessionCoordinatorTests {

    @Test func sessionCoordinatorStartsInStoppedState() async throws {
        let coordinator = SessionCoordinator()

        #expect(coordinator.isRecording == false)
        #expect(coordinator.isTestRunning == false)
    }

    @Test func sessionCoordinatorStartsWithNoErrors() async throws {
        let coordinator = SessionCoordinator()

        #expect(coordinator.errorMessage == nil)
    }
}

@MainActor
struct CodeGenerationUtilitiesTests {

    @Test func sanitizeClassNameRemovesSpaces() async throws {
        let input = "My Test Screen"
        let result = CodeGenerationUtilities.sanitizeClassName(input)

        #expect(result == "MyTestScreen")
    }

    @Test func sanitizeClassNameRemovesSpecialCharacters() async throws {
        let input = "Test-Screen (Final)"
        let result = CodeGenerationUtilities.sanitizeClassName(input)

        #expect(result == "TestScreenFinal")
    }

    @Test func sanitizeFunctionNameStartsWithLowercase() async throws {
        let input = "My Test Screen"
        let result = CodeGenerationUtilities.sanitizeFunctionName(input)

        #expect(result == "myTestScreen")
    }

    @Test func extractTextFromScreenNameFindsQuotedText() async throws {
        let input = "After typing 'hello world' into field"
        let result = CodeGenerationUtilities.extractTextFromScreenName(input)

        #expect(result == "hello world")
    }

    @Test func extractTextFromScreenNameFallsBackToDefault() async throws {
        let input = "Some screen name without quotes"
        let result = CodeGenerationUtilities.extractTextFromScreenName(input)

        #expect(result == "test input")
    }
}

@MainActor
struct InteractionCoordinatorTests {

    @Test func coordinatorStartsNotInteracting() async throws {
        let service = InteractionService(
            communicationService: createTestCommunicationService()
        )
        let coordinator = InteractionCoordinator(interactionService: service)

        #expect(coordinator.isInteracting == false)
    }
}

@MainActor
struct CodeGenerationStrategyTests {

    @Test func appiumGeneratorCreatesCodeWithBundleID() async throws {
        let generator = AppiumGenerator()
        let flowGroup = createTestFlowGroup()
        let screens = createTestScreens()
        let edges = createTestEdges()

        let code = generator.generate(
            flowGroup: flowGroup,
            screens: screens,
            edges: edges,
            bundleID: "com.test.app"
        )

        #expect(code.contains("com.test.app"))
    }

    @Test func maestroGeneratorCreatesValidYAML() async throws {
        let generator = MaestroGenerator()
        let flowGroup = createTestFlowGroup()
        let screens = createTestScreens()
        let edges = createTestEdges()

        let code = generator.generate(
            flowGroup: flowGroup,
            screens: screens,
            edges: edges,
            bundleID: "com.test.app"
        )

        #expect(code.contains("appId:"))
    }

    @Test func xcuiTestGeneratorCreatesSwiftCode() async throws {
        let generator = XCUITestGenerator()
        let flowGroup = createTestFlowGroup()
        let screens = createTestScreens()
        let edges = createTestEdges()

        let code = generator.generate(
            flowGroup: flowGroup,
            screens: screens,
            edges: edges,
            bundleID: "com.test.app"
        )

        #expect(code.contains("XCTestCase"))
        #expect(code.contains("func test"))
    }
}

func createTestCommunicationService() -> CommunicationService {
    TestCommunicationService()
}

final class TestCommunicationService: CommunicationService {
    init() {
        super.init(deviceIP: "test")
    }

    override func sendCommand(_ command: Command) async throws -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let jsonString = """
        {
            "timestamp": "\(ISO8601DateFormatter().string(from: Date()))",
            "elements": [],
            "screenshot": null,
            "appFrame": null,
            "screenBounds": null,
            "displayScale": null
        }
        """
        return jsonString
    }
}

func createTestFlowGroup() -> FlowGroup {
    FlowGroup(
        id: UUID(),
        name: "Test Flow"
    )
}

func createTestScreens() -> [CapturedScreen] {
    []
}

func createTestEdges() -> [NavigationEdge] {
    []
}
