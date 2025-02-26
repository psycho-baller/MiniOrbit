//
//  MiniOrbitUITests.swift
//  MiniOrbitUITests
//
//  Created by Rami Maalouf on 2025-02-08.
//

import XCTest

final class MiniOrbitUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = true

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testAccesibilityProfileView() throws {
        /// First launch the app
        let app = XCUIApplication()
        app.launch()
        
        /// Next navigate to the page you would like to test
        /// In this case we will need to click submit on the first page then use the tab bar to switch to the profile

        /// Check if we need to submit (are we on onboarding view?)
        let submitButton = app.buttons["Submit"]
        if submitButton.exists {
            submitButton.tap()
        }
        
        // app.tabBars.buttons["Profile"].tap()
        
        /// Wait for tab bar to appear and then tap Profile
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 1))
        profileTab.tap()
        
        
        /// Once at the correct page create tests

        /// Verify profile elements exist
        /// These tests can also help with accessibilty because in order for XCTest to find the views they must be accessibility elements
        XCTAssertTrue(app.staticTexts["nameText"].exists)
        XCTAssertTrue(app.staticTexts["email"].exists)
        XCTAssertTrue(app.staticTexts["university"].exists)
        XCTAssertTrue(app.staticTexts["interests"].exists)
        XCTAssertTrue(app.staticTexts["universityId"].exists)
        XCTAssertTrue(app.staticTexts["verified"].exists)
        
        /// The audit can report multiple issues but with "continueAfterFailure = false" it will stop at the first issue.
        /// Change continueAfterFailure = true to allow the audit to report multiple issues
        try app.performAccessibilityAudit()
        
        
        /// You can set specific features for the audit to check for
        try app.performAccessibilityAudit(for:  XCUIAccessibilityAuditType.textClipped)
        
    }
    
    
    
    

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
