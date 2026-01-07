//
//  GeneratedTestsTest.swift
//  Studio
//
//  Created by Kilo Loco on 1/7/26.
//

//let springboardApp = XCUIApplication(bundleIdentifier: "com.apple.springboard")
//springboardApp.statusBars.element(boundBy: 0).tap()

//XCUIDevice.shared.press(.home)

import XCTest

final class UndoShowFewerShortsUITests: XCTestCase {

    var youtubeApp: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        youtubeApp = XCUIApplication(bundleIdentifier: "com.google.ios.youtube")
        youtubeApp.launch()
    }

    override func tearDownWithError() throws {
        youtubeApp.terminate()
    }

    func testundoShowFewerShorts() throws {
        youtubeApp/*@START_MENU_TOKEN@*/.buttons["Action menu"].buttons["eml.overflow_button"].firstMatch/*[[".buttons.matching(identifier: \"eml.overflow_button\").element(boundBy: 1)",".buttons[\"Action menu\"]",".buttons.firstMatch",".buttons[\"Action menu\"].firstMatch",".buttons[\"eml.overflow_button\"].firstMatch"],[[[-1,1,1],[-1,0]],[[-1,4],[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/.tap()
        youtubeApp/*@START_MENU_TOKEN@*/.otherElements["Horizontal scroll bar, 1 page"]/*[[".scrollViews.otherElements[\"Horizontal scroll bar, 1 page\"]",".otherElements[\"Horizontal scroll bar, 1 page\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()
        youtubeApp.buttons.matching(identifier: "Undo").element(boundBy: 1).tap()

        
//        // Navigate from 'Initial Screen' to 'After tap on Action menu'
//        app.buttons["eml.overflow_button"].tap()
//
//        // Wait for UI to settle
//        Thread.sleep(forTimeInterval: 0.5)
//
//        // Navigate from 'After tap on Action menu' to 'After tap on Show fewer Shorts'
//        app.buttons["0"].tap()
//
//        // Wait for UI to settle
//        Thread.sleep(forTimeInterval: 0.5)
//
//        // Navigate from 'After tap on Show fewer Shorts' to 'After tap on Undo'
//        app.buttons["Undo"].tap()
//
//        // Wait for UI to settle
//        Thread.sleep(forTimeInterval: 0.5)
    }
}


