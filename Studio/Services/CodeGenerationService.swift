import Foundation

class CodeGenerationService {
    enum TestFramework {
        case xcuiTest
        case maestro
        case appium
    }

    private let xcuiTestGenerator = XCUITestGenerator()
    private let maestroGenerator = MaestroGenerator()
    private let appiumGenerator = AppiumGenerator()

    func generate(
        framework: TestFramework,
        flowGroup: FlowGroup,
        screens: [CapturedScreen],
        edges: [NavigationEdge],
        bundleID: String
    ) -> String {
        let strategy: CodeGenerationStrategy

        switch framework {
        case .xcuiTest:
            strategy = xcuiTestGenerator
        case .maestro:
            strategy = maestroGenerator
        case .appium:
            strategy = appiumGenerator
        }

        return strategy.generate(
            flowGroup: flowGroup,
            screens: screens,
            edges: edges,
            bundleID: bundleID
        )
    }
}
