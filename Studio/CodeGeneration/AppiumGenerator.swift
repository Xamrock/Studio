import Foundation

class AppiumGenerator: CodeGenerationStrategy {
    func generate(
        flowGroup: FlowGroup,
        screens: [CapturedScreen],
        edges: [NavigationEdge],
        bundleID: String
    ) -> String {
        var code = """
        const { remote } = require('webdriverio');

        describe('\(CodeGenerationUtilities.sanitizeClassName(flowGroup.name)) Flow', () => {
            let driver;

            beforeAll(async () => {
                const opts = {
                    path: '/wd/hub',
                    port: 4723,
                    capabilities: {
                        platformName: 'iOS',
                        'appium:automationName': 'XCUITest',
                        'appium:deviceName': 'iPhone Simulator',
                        'appium:bundleId': '\(bundleID)',
                        'appium:app': '/path/to/your/app.app'
                    }
                };
                driver = await remote(opts);
            });

            afterAll(async () => {
                if (driver) {
                    await driver.deleteSession();
                }
            });

            it('should complete \(flowGroup.name.lowercased()) flow', async () => {

        """

        let flowScreens = screens.filter { screen in
            screen.flowGroupIds.contains(flowGroup.id)
        }

        let path = CodeGenerationUtilities.buildTestPath(screens: flowScreens, edges: edges)

        for step in path {
            code += generateStep(step, indentation: "        ")
        }

        code += """
            });
        });

        """

        return code
    }

    private func generateStep(_ step: TestStep, indentation: String) -> String {
        var code = "\n"
        code += "\(indentation)// \(step.description)\n"

        switch step.action {
        case .tap(let identifier, let label):
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)const element = await driver.$('~\(identifier)');\n"
                code += "\(indentation)await element.click();\n"
            } else if !label.isEmpty {
                code += "\(indentation)const element = await driver.$('~\(label)');\n"
                code += "\(indentation)await element.click();\n"
            } else {
                code += "\(indentation)// TODO: Tap element (identifier unknown)\n"
            }

        case .typeText(let identifier, let text):
            code += "\(indentation)const textField = await driver.$('~\(identifier)');\n"
            code += "\(indentation)await textField.click();\n"
            code += "\(indentation)await textField.setValue('\(text)');\n"

        case .wait(let seconds):
            code += "\(indentation)await driver.pause(\(Int(seconds * 1000)));\n"

        case .verify(let condition):
            code += "\(indentation)// TODO: Verify \(condition)\n"

        case .swipe(let direction, let identifier, let label):
            let elementLocator = !identifier.isEmpty && identifier != "manual_edge"
                ? "'~\(identifier)'"
                : (!label.isEmpty ? "'~\(label)'" : "")

            if !elementLocator.isEmpty {
                code += "\(indentation)const element = await driver.$(\(elementLocator));\n"
                code += "\(indentation)await element.touchAction([\n"
            } else {
                code += "\(indentation)await driver.touchAction([\n"
            }

            switch direction {
            case .up:
                code += "\(indentation)    { action: 'press', x: 200, y: 400 },\n"
                code += "\(indentation)    { action: 'wait', ms: 100 },\n"
                code += "\(indentation)    { action: 'moveTo', x: 200, y: 100 },\n"
                code += "\(indentation)    'release'\n"
            case .down:
                code += "\(indentation)    { action: 'press', x: 200, y: 100 },\n"
                code += "\(indentation)    { action: 'wait', ms: 100 },\n"
                code += "\(indentation)    { action: 'moveTo', x: 200, y: 400 },\n"
                code += "\(indentation)    'release'\n"
            case .left:
                code += "\(indentation)    { action: 'press', x: 300, y: 200 },\n"
                code += "\(indentation)    { action: 'wait', ms: 100 },\n"
                code += "\(indentation)    { action: 'moveTo', x: 100, y: 200 },\n"
                code += "\(indentation)    'release'\n"
            case .right:
                code += "\(indentation)    { action: 'press', x: 100, y: 200 },\n"
                code += "\(indentation)    { action: 'wait', ms: 100 },\n"
                code += "\(indentation)    { action: 'moveTo', x: 300, y: 200 },\n"
                code += "\(indentation)    'release'\n"
            }
            code += "\(indentation)]);\n"

        case .longPress(let identifier, let label, let duration):
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)const element = await driver.$('~\(identifier)');\n"
                code += "\(indentation)await element.touchAction([\n"
                code += "\(indentation)    { action: 'press' },\n"
                code += "\(indentation)    { action: 'wait', ms: \(Int(duration * 1000)) },\n"
                code += "\(indentation)    'release'\n"
                code += "\(indentation)]);\n"
            } else if !label.isEmpty {
                code += "\(indentation)const element = await driver.$('~\(label)');\n"
                code += "\(indentation)await element.touchAction([\n"
                code += "\(indentation)    { action: 'press' },\n"
                code += "\(indentation)    { action: 'wait', ms: \(Int(duration * 1000)) },\n"
                code += "\(indentation)    'release'\n"
                code += "\(indentation)]);\n"
            } else {
                code += "\(indentation)// TODO: Long press element (identifier unknown)\n"
            }

        case .doubleTap(let identifier, let label):
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)const element = await driver.$('~\(identifier)');\n"
                code += "\(indentation)await element.click();\n"
                code += "\(indentation)await element.click();\n"
            } else if !label.isEmpty {
                code += "\(indentation)const element = await driver.$('~\(label)');\n"
                code += "\(indentation)await element.click();\n"
                code += "\(indentation)await element.click();\n"
            } else {
                code += "\(indentation)// TODO: Double tap element (identifier unknown)\n"
            }

        case .tapCoordinate(let x, let y):
            code += "\(indentation)await driver.touchAction([\n"
            code += "\(indentation)    { action: 'tap', x: \(Int(x)), y: \(Int(y)) }\n"
            code += "\(indentation)]);\n"

        case .tapCell(let index, let identifier, let label):
            if !identifier.isEmpty && identifier != "manual_edge" {
                code += "\(indentation)const cells = await driver.$$('~\(identifier)');\n"
                code += "\(indentation)await cells[\(index)].click();\n"
            } else if !label.isEmpty {
                code += "\(indentation)const cells = await driver.$$('~\(label)');\n"
                code += "\(indentation)await cells[\(index)].click();\n"
            } else {
                code += "\(indentation)const cells = await driver.$$('-ios class chain:**/XCUIElementTypeCell');\n"
                code += "\(indentation)await cells[\(index)].click();\n"
            }
        }

        return code
    }
}
