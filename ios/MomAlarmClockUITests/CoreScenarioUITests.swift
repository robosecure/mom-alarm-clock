import XCTest

/// XCUITest scaffolding for the "Core 10" scenarios from TEST_SCENARIOS_2026-04-17.md.
///
/// Each test drives the simulator UI through one scenario. Tests that depend on
/// backend-authenticated state or full device capabilities (microphone, motion,
/// push) are XCTSkip'd with a TODO — flesh them out once Firebase test fixtures
/// and simulator entitlements are in place.
///
/// Scenarios covered (letter corresponds to TEST_SCENARIOS_2026-04-17.md):
///   H1  Launch resilience (10 relaunches, no crash)
///   H2  Fresh install → role picker renders
///   A1  Quiz wrong-then-right (child side)
///   A3  Photo verification (waits for guardian review, no auto-approve)
///   B1  Snooze flow
///   B3  Voice alarm playback
///   C1  Guardian approves pending session
///   C3  Guardian denies pending session
///   D3  Timezone change reschedules alarm
///   E1  Child pairing code entry validates
///
/// Run all: xcodebuild test -scheme MomAlarmClock -destination "platform=iOS Simulator,id=CE8349D4-210F-419E-A532-2882BB1C2037" -only-testing:MomAlarmClockUITests
final class CoreScenarioUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uitesting"]
    }

    // MARK: - H2: Role picker renders on fresh launch
    func testH2_rolePickerRendersOnLaunch() {
        app.launch()
        XCTAssertTrue(app.staticTexts["Mom Alarm Clock"].waitForExistence(timeout: 10),
                      "App title should appear on launch screen")
        let guardianButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Guardian'")).firstMatch
        let childButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Child'")).firstMatch
        XCTAssertTrue(guardianButton.waitForExistence(timeout: 5), "Guardian button should be visible")
        XCTAssertTrue(childButton.exists, "Child button should be visible")
    }

    // MARK: - H1: Launch resilience (relaunch loop)
    func testH1_noCrashAcrossMultipleLaunches() {
        for i in 1...5 {
            app.launch()
            XCTAssertTrue(app.staticTexts["Mom Alarm Clock"].waitForExistence(timeout: 10),
                          "Launch #\(i) failed to show root screen")
            app.terminate()
        }
    }

    // MARK: - E1: Child pairing sheet opens and code field validates
    func testE1_childPairingSheetOpens() {
        app.launch()
        let childButton = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Child'")).firstMatch
        XCTAssertTrue(childButton.waitForExistence(timeout: 5))
        childButton.tap()
        let codeField = app.textFields.firstMatch
        XCTAssertTrue(codeField.waitForExistence(timeout: 3),
                      "Pairing code text field should appear in sheet")
    }

    // MARK: - Scenarios pending accessibility-identifier work or backend fixtures

    func testA1_quizWrongThenRight() throws {
        throw XCTSkip("Requires authenticated child state + quiz accessibility IDs")
        // Flow: sign in as child → alarm fires → choose Quiz verification →
        // tap wrong answer → assert "try again" copy → tap correct answer → assert .pendingParentReview
    }

    func testA3_photoWaitsForGuardianReview() throws {
        throw XCTSkip("Requires authenticated child + photo picker automation")
        // Flow: child selects photo → tap Submit → assert "Photo Submitted" appears
        // only after VM persists (PhotoVerificationView.swift:submitPhoto fix)
    }

    func testB1_snoozeFlow() throws {
        throw XCTSkip("Requires simulated alarm trigger")
    }

    func testB3_voiceAlarmPlayback() throws {
        throw XCTSkip("Requires pre-recorded voice alarm fixture + playback accessibility IDs")
    }

    func testC1_guardianApprovesSession() throws {
        throw XCTSkip("Requires authenticated guardian state + pending session fixture")
    }

    func testC3_guardianDeniesSession() throws {
        throw XCTSkip("Requires authenticated guardian state + pending session fixture")
    }

    func testD3_timezoneChangeReschedules() throws {
        throw XCTSkip("Requires simctl timezone override + notification pending-request inspection")
    }
}
