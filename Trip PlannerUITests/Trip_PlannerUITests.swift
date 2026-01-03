//
//  Trip_PlannerUITests.swift
//  Trip PlannerUITests
//
//  Created by Piotr Osmenda on 12/16/25.
//

import XCTest

final class Trip_PlannerUITests: XCTestCase {

    override func setUpWithError() throws {

        continueAfterFailure = false

    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
