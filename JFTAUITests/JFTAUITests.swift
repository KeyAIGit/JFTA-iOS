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
        let button = app.buttons.matching(identifier: id).firstMatch
        let e = button.exists ? button : element(id)
        if !e.exists { XCTAssertTrue(e.waitForExistence(timeout: 5), "Missing \(id)", file: file, line: line) }
        for _ in 0..<7 { if e.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(e.isHittable, "Not hittable: \(id)", file: file, line: line); e.tap()
    }
    private func tab(_ title: String) {
        let button = app.tabBars.buttons[title]; XCTAssertTrue(button.waitForExistence(timeout: 8)); button.tap()
    }
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func type(_ id: String, _ text: String) { let e = element(id); XCTAssertTrue(e.waitForExistence(timeout: 8)); e.tap(); e.typeText(text) }
    private func back() { let button = app.navigationBars.buttons.element(boundBy: 0); XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap() }

    func testWelcomeHasRealFieldsAndValidation() {
        launch(welcome: true); shot("01-welcome")
        tap("welcome.enter")
        XCTAssertTrue(app.alerts["Could not complete action"].waitForExistence(timeout: 3)); app.alerts.buttons["OK"].tap()
        type("welcome.name", "Road Tester"); type("welcome.email", "tester@example.com"); tap("welcome.enter")
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
        tap("profile.save"); XCTAssertTrue(app.alerts["Profile saved"].waitForExistence(timeout: 3)); app.alerts.buttons["OK"].tap(); shot("25-profile")
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
        let done = app.buttons["Done"].firstMatch; XCTAssertTrue(done.waitForExistence(timeout: 8)); shot("document-quicklook"); done.tap()
        app.buttons["Document actions"].firstMatch.tap(); app.buttons["Delete local copy"].firstMatch.tap()
        let confirm = app.sheets.buttons["Delete local copy"].firstMatch; XCTAssertTrue(confirm.waitForExistence(timeout: 5)); confirm.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element("document.preview")); waitForExpectations(timeout: 8); shot("documents-after-delete")
    }
    func testKeyboardDismissAndInvalidProfileIsNotSaved() {
        launch(); tab("More"); tap("more.profile"); type("profile.email", "invalid")
        tap("keyboard.done"); expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.keyboards); waitForExpectations(timeout: 5)
        tap("profile.save"); XCTAssertTrue(app.alerts["Could not complete action"].waitForExistence(timeout: 5)); app.alerts.buttons["OK"].tap(); shot("profile-validation")
        app.terminate(); launch(reset: false); tab("More"); tap("more.profile"); XCTAssertNotEqual(element("profile.email").value as? String, "invalid")
    }
}
