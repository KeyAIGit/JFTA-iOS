import XCTest

final class JFTAUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false; executionTimeAllowance = 300 }
    private func launch(reset: Bool = true, welcome: Bool = false) {
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if reset { app.launchArguments.append("--reset") }
        if welcome { app.launchArguments.append("--welcome") }
        app.launch()
    }
    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        // Lazy grids do not expose off-screen cards before scrolling creates them.
        for _ in 0..<8 {
            let button = app.buttons.matching(identifier: id).firstMatch
            let e = button.exists ? button : element(id)
            if e.exists && e.isHittable { e.tap(); return }
            app.swipeUp()
        }
        XCTFail("Missing or offscreen: \(id)", file: file, line: line)
    }
    private func tab(_ title: String) {
        let button = app.tabBars.buttons[title]; XCTAssertTrue(button.waitForExistence(timeout: 8)); button.tap()
    }
    private func dismissSystemTypingHint() {
        let tip = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Speed up your typing")).firstMatch
        if tip.waitForExistence(timeout: 0.5) && app.buttons["Continue"].exists { app.buttons["Continue"].tap() }
    }
    private func shot(_ name: String) {
        dismissSystemTypingHint()
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func type(_ id: String, _ text: String) {
        let e = element(id); XCTAssertTrue(e.waitForExistence(timeout: 8)); e.tap()
        dismissSystemTypingHint()
        e.typeText(text)
    }
    private func back() { let button = app.navigationBars.buttons.element(boundBy: 0); XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap() }

    func testWelcomeHasRealFieldsAndValidation() {
        launch(welcome: true); shot("01-welcome")
        tap("welcome.enter")
        XCTAssertTrue(app.alerts["Could not complete action"].waitForExistence(timeout: 3)); app.alerts.buttons["OK"].tap()
        type("welcome.name", "Road Tester\n"); type("welcome.email", "tester@example.com\n"); tap("welcome.enter")
        XCTAssertTrue(app.staticTexts["Road Tester"].waitForExistence(timeout: 5)); shot("03-home")
        app.terminate(); launch(reset: false); XCTAssertTrue(app.staticTexts["Road Tester"].waitForExistence(timeout: 5))
    }
    func testRequestDraftSurvivesRestart() {
        launch(); tab("Cases"); tap("cases.startRequest"); shot("07-request-form")
        type("request.title", "Inspection sample"); type("request.details", "Please review this non-sensitive sample document."); tap("request.save")
        XCTAssertTrue(app.alerts["Draft saved"].waitForExistence(timeout: 5)); app.alerts.buttons["Done"].tap()
        tap("case.Inspection sample"); XCTAssertTrue(app.staticTexts["Local draft"].waitForExistence(timeout: 5)); shot("06-case-details")
        app.terminate(); launch(reset: false); tab("Cases"); tap("case.Inspection sample"); XCTAssertTrue(element("caseDetail.edit").exists)
    }
    func testEmptyRequestIsRejected() {
        launch(); tab("Cases"); tap("cases.startRequest"); tap("request.save")
        XCTAssertTrue(app.alerts["Could not complete action"].waitForExistence(timeout: 3)); shot("request-validation")
    }
    func testSavedBenefitSurvivesRestart() {
        launch(); tab("Benefits"); tap("offer.fuel"); tap("offer.save")
        XCTAssertEqual(element("offer.save").label, "Remove from saved"); shot("15-offer-details")
        app.terminate(); launch(reset: false); tab("Benefits"); tap("offer.fuel"); XCTAssertEqual(element("offer.save").label, "Remove from saved")
    }
    func testProfileEditSurvivesRestart() {
        launch(); tab("More"); tap("more.profile"); type("profile.name", " UI")
        let expected = element("profile.name").value as? String
        tap("profile.save"); XCTAssertTrue(app.alerts["Profile saved"].waitForExistence(timeout: 3)); app.alerts.buttons["OK"].tap()
        expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.keyboards); waitForExpectations(timeout: 5)
        shot("25-profile")
        app.terminate(); launch(reset: false); tab("More"); tap("more.profile"); XCTAssertEqual(element("profile.name").value as? String, expected)
    }
    func testLocalDocumentImportPersists() {
        launch(); tab("More"); tap("more.documents"); tap("documents.testSample")
        XCTAssertTrue(element("document.preview").waitForExistence(timeout: 8)); shot("24-documents")
        app.terminate(); launch(reset: false); tab("More"); tap("more.documents"); XCTAssertTrue(element("document.preview").waitForExistence(timeout: 8))
        // Uses a fixture to exercise the local import path. External Files/iCloud providers still need manual testing.
    }
    func testLocalCommunityPostAndReplyPersist() {
        launch(); tab("More"); tap("more.community"); tap("community.compose")
        type("post.title", "Road notes"); type("post.body", "This discussion is a local UI test."); tap("post.save")
        tap("post.Road notes"); type("thread.reply", "A local reply"); tap("thread.saveReply")
        XCTAssertTrue(app.staticTexts["A local reply"].waitForExistence(timeout: 5)); shot("19-community-thread")
        app.terminate(); launch(reset: false); tab("More"); tap("more.community"); tap("post.Road notes"); XCTAssertTrue(app.staticTexts["A local reply"].waitForExistence(timeout: 5))
    }
    func testMoreDestinationsAreNative() {
        launch(); tab("More")
        let routes: [(String, String)] = [("memberPass", "Member pass"), ("notifications", "Notifications"), ("resources", "Resources"), ("marketplace", "Marketplace"), ("membership", "Membership & billing"), ("referral", "Refer a driver"), ("help", "Help & support")]
        for (id, title) in routes {
            tap("more." + id); XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5)); shot("more-" + id); back()
        }
    }
    func testResourcesAndMarketplaceDetails() {
        launch(); tab("More"); tap("more.resources"); tap("article.documents"); tap("article.save"); shot("17-resource")
        back(); back(); tap("more.marketplace"); tap("listing.trailer"); tap("listing.save"); XCTAssertEqual(element("listing.save").label, "Remove from saved"); shot("21-listing")
    }
    func testTabScreens() {
        launch()
        for name in ["Home", "Cases", "Benefits", "More"] { tab(name); XCTAssertTrue(element("localBetaNotice").exists || name == "Benefits" || name == "More"); shot("tab-" + name.lowercased()) }
    }

    private func checkService(_ kind: String) {
        launch(); tap("home.service." + kind)
        XCTAssertTrue(app.navigationBars[kind + " support"].waitForExistence(timeout: 5)); shot("service-" + kind.lowercased())
        if kind == "Health" || kind == "Financial" { tap("service.consultation"); XCTAssertTrue(app.navigationBars["Consultation draft"].waitForExistence(timeout: 5)); shot("consultation-" + kind.lowercased()); back() }
        tap("service.start"); XCTAssertTrue(element("request.title").waitForExistence(timeout: 5)); shot("request-" + kind.lowercased())
    }
    func testServiceLegal() { checkService("Legal") }
    func testServiceHealth() { checkService("Health") }
    func testServiceFinancial() { checkService("Financial") }
    func testServiceBenefits() { checkService("Benefits") }
    func testQuickLookPreviewAndLocalDelete() {
        launch(); tab("More"); tap("more.documents"); tap("documents.testSample"); tap("document.preview")
        let preview = app.otherElements["QLPreviewControllerView"].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 8))
        let done = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "QLOverlayDoneButtonAccessibilityIdentifier", "Done")).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8)); shot("document-quicklook"); done.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: preview); waitForExpectations(timeout: 8)
        tap("document.actions"); tap("document.delete"); tap("documents.confirmDelete")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element("document.preview")); waitForExpectations(timeout: 8); shot("documents-after-delete")
    }
    func testKeyboardDismissAndInvalidProfileIsNotSaved() {
        launch(); tab("More"); tap("more.profile"); type("profile.email", "invalid")
        tap("keyboard.done"); expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.keyboards); waitForExpectations(timeout: 5)
        tap("profile.save"); XCTAssertTrue(app.alerts["Could not complete action"].waitForExistence(timeout: 5)); app.alerts.buttons["OK"].tap(); shot("profile-validation")
        app.terminate(); launch(reset: false); tab("More"); tap("more.profile"); XCTAssertNotEqual(element("profile.email").value as? String, "invalid")
    }


    func testUnsavedDraftCanKeepEditingThenDiscard() {
        launch(); tab("Cases"); tap("cases.startRequest")
        type("request.title", "Unsaved road note")
        type("request.details", "This non-sensitive draft should not be lost by accident.")
        tap("request.back")
        XCTAssertTrue(app.buttons["Keep editing"].waitForExistence(timeout: 5)); shot("request-unsaved-warning")
        app.buttons["Keep editing"].tap()
        XCTAssertEqual(element("request.title").value as? String, "Unsaved road note")
        tap("request.back"); app.buttons["Discard changes"].tap()
        XCTAssertTrue(element("cases.startRequest").waitForExistence(timeout: 5))
        XCTAssertFalse(element("case.Unsaved road note").exists)
    }
    func testDiscardedEditPreservesPreviouslySavedDraft() {
        launch(); tab("Cases"); tap("cases.startRequest")
        type("request.title", "Preserved road note")
        type("request.details", "This saved sample remains unchanged after discarding an edit.")
        tap("request.save")
        XCTAssertTrue(app.alerts["Draft saved"].waitForExistence(timeout: 5)); app.alerts.buttons["Done"].tap()
        tap("case.Preserved road note"); tap("caseDetail.edit")
        type("request.title", " changed"); tap("request.back")
        XCTAssertTrue(app.buttons["Discard changes"].waitForExistence(timeout: 5)); app.buttons["Discard changes"].tap()
        XCTAssertEqual(element("caseDetail.title").label, "Preserved road note")
        app.terminate(); launch(reset: false); tab("Cases"); tap("case.Preserved road note")
        XCTAssertEqual(element("caseDetail.title").label, "Preserved road note"); shot("request-preserved-after-discard")
    }
}
