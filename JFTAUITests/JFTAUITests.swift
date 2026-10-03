import XCTest

final class JFTAUITests: XCTestCase {
    let app = XCUIApplication()
    override func setUpWithError() throws { continueAfterFailure = false; executionTimeAllowance = 300 }
    private func launch(reset: Bool = true, welcome: Bool = false, largeText: Bool = false) {
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if reset { app.launchArguments.append("--reset") }
        if welcome { app.launchArguments.append("--welcome") }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
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
    @discardableResult
    private func dismissSystemTypingHint() -> Bool {
        let tip = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Speed up your typing")).firstMatch
        if tip.exists && app.buttons["Continue"].exists { app.buttons["Continue"].tap(); return true }
        return false
    }
    private func shot(_ name: String) {
        dismissSystemTypingHint()
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func type(_ id: String, _ text: String) {
        let e = element(id); XCTAssertTrue(e.waitForExistence(timeout: 8))
        // Native keyboard/tutorial transitions can consume a focus tap. Type only once, after readiness.
        for attempt in 1...3 {
            XCTContext.runActivity(named: "Focus \(id), attempt \(attempt)") { _ in e.tap() }
            if dismissSystemTypingHint() { e.tap() }
            if app.keyboards.firstMatch.waitForExistence(timeout: 4) {
                e.typeText(text)
                // Simulator key delivery may outlive typeText(). Never save a partially delivered input.
                let entered = text.trimmingCharacters(in: .newlines)
                if !entered.isEmpty {
                    let complete = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", entered), object: e)
                    XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 20), .completed, "Input was not fully delivered to \(id)")
                }
                return
            }
        }
        XCTFail("Keyboard did not become available for \(id)")
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
        let done = app.buttons.matching(identifier: "document.preview.close").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8)); XCTAssertTrue(done.isHittable); shot("document-quicklook"); done.tap()
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
        XCTAssertTrue(app.buttons.matching(identifier: "request.keepEditing").firstMatch.waitForExistence(timeout: 5)); shot("request-unsaved-warning")
        app.buttons.matching(identifier: "request.keepEditing").firstMatch.tap()
        XCTAssertEqual(element("request.title").value as? String, "Unsaved road note")
        tap("request.back"); app.buttons.matching(identifier: "request.discard").firstMatch.tap()
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
        XCTAssertTrue(app.buttons.matching(identifier: "request.discard").firstMatch.waitForExistence(timeout: 5)); app.buttons.matching(identifier: "request.discard").firstMatch.tap()
        XCTAssertEqual(element("caseDetail.title").label, "Preserved road note")
        app.terminate(); launch(reset: false); tab("Cases"); tap("case.Preserved road note")
        XCTAssertEqual(element("caseDetail.title").label, "Preserved road note"); shot("request-preserved-after-discard")
    }
}


extension JFTAUITests {
    private func createDraft(_ title: String) {
        tab("Cases"); tap("cases.startRequest"); type("request.title", title)
        type("request.details", "Non-sensitive sample request for checking local interactions.")
        tap("request.save"); XCTAssertTrue(app.alerts["Draft saved"].waitForExistence(timeout: 5)); app.alerts.buttons["Done"].tap()
        tap("case." + title)
    }
    func testHomeWorkspaceCardsOpenRealDestinations() {
        launch(); tap("home.drafts"); XCTAssertTrue(element("cases.startRequest").waitForExistence(timeout: 5)); back()
        tap("home.savedOffers"); XCTAssertTrue(app.switches["benefits.savedOnly"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["benefits.savedOnly"].value as? String, "1"); shot("home-saved-offers"); back()
        tap("home.documents"); XCTAssertTrue(element("documents.import").waitForExistence(timeout: 5))
    }
    func testProfileUnsavedChangesCanBeKeptOrDiscarded() {
        launch(); tab("More"); tap("more.profile"); type("profile.name", " changed"); tap("profile.back")
        tap("profile.keepEditing"); XCTAssertEqual(element("profile.name").value as? String, "Test Driver changed")
        tap("profile.back"); tap("profile.discard"); tap("more.profile")
        XCTAssertEqual(element("profile.name").value as? String, "Test Driver"); shot("profile-retained")
    }
    func testDiscussionCanBeEditedAndDeletedWithoutLosingReplies() {
        launch(); tab("More"); tap("more.community"); tap("community.compose")
        type("post.title", "Editable discussion"); type("post.body", "This is a non-sensitive discussion draft."); tap("post.save")
        tap("post.Editable discussion"); type("thread.reply", "Keep this reply"); tap("thread.saveReply")
        tap("thread.edit"); type("post.title", " updated"); tap("post.save")
        XCTAssertEqual(element("thread.title").label, "Editable discussion updated")
        XCTAssertTrue(app.staticTexts["Keep this reply"].exists); shot("discussion-edited")
        tap("thread.delete"); tap("thread.confirmDelete"); XCTAssertTrue(element("community.compose").waitForExistence(timeout: 5))
        app.terminate(); launch(reset: false); tab("More"); tap("more.community"); XCTAssertFalse(element("post.Editable discussion updated").exists)
    }
    func testPostComposerProtectsUnsavedText() {
        launch(); tab("More"); tap("more.community"); tap("community.compose")
        type("post.title", "Unsaved discussion"); tap("post.back"); tap("post.keepEditing")
        XCTAssertEqual(element("post.title").value as? String, "Unsaved discussion")
        tap("post.back"); tap("post.discard"); XCTAssertTrue(element("community.compose").waitForExistence(timeout: 5))
        XCTAssertFalse(element("post.Unsaved discussion").exists)
    }
    func testDraftAttachmentsToggleAndDeleteWithoutOpeningPreview() {
        launch(); createDraft("Attachment check"); tap("caseDetail.documents"); tap("documents.testSample")
        let attachment = element("document.attachment"); XCTAssertTrue(attachment.waitForExistence(timeout: 8))
        XCTAssertEqual(attachment.value as? String, "Attached")
        tap("document.attachment"); XCTAssertEqual(attachment.value as? String, "Not attached")
        XCTAssertFalse(element("document.preview.close").exists)
        tap("document.attachment"); XCTAssertEqual(attachment.value as? String, "Attached"); shot("draft-file-attached")
        tap("document.actions"); tap("document.delete"); tap("documents.confirmDelete")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element("document.preview")); waitForExpectations(timeout: 8)
        back(); XCTAssertTrue(element("caseDetail.documents").label.contains("0 local reference"))
        app.terminate(); launch(reset: false); tab("Cases"); tap("case.Attachment check")
        XCTAssertTrue(element("caseDetail.documents").label.contains("0 local reference"))
    }
    func testDraftDeleteFromDetailKeepsLocalDocuments() {
        launch(); createDraft("Delete draft only"); tap("caseDetail.documents"); tap("documents.testSample")
        XCTAssertTrue(element("document.preview").waitForExistence(timeout: 8)); back(); tap("caseDetail.delete"); tap("caseDetail.confirmDelete")
        XCTAssertTrue(element("cases.startRequest").waitForExistence(timeout: 5)); XCTAssertFalse(element("case.Delete draft only").exists)
        tab("More"); tap("more.documents"); XCTAssertTrue(element("document.preview").waitForExistence(timeout: 8)); shot("files-retained-after-draft-delete")
    }
    func testSystemFilesPickerOpensAndCancelsWithoutFalseImport() {
        launch(); tab("More"); tap("more.documents"); tap("documents.import")
        let cancel = app.buttons["Cancel"].firstMatch; XCTAssertTrue(cancel.waitForExistence(timeout: 10)); shot("system-files-picker")
        cancel.tap(); XCTAssertTrue(element("documents.import").waitForExistence(timeout: 5))
        XCTAssertFalse(element("document.preview").exists); XCTAssertFalse(app.alerts["Could not complete action"].exists)
    }
    func testMembershipPreferenceRemainsAfterRelaunch() {
        launch(); tab("More"); tap("more.membership")
        let standard = app.segmentedControls.buttons["Standard"]; XCTAssertTrue(standard.waitForExistence(timeout: 5)); standard.tap()
        tap("membership.save"); XCTAssertTrue(app.alerts["Preference saved"].waitForExistence(timeout: 5)); app.alerts.buttons["OK"].tap()
        app.terminate(); launch(reset: false); tab("More"); tap("more.membership")
        XCTAssertTrue(app.segmentedControls.buttons["Standard"].isSelected); shot("membership-preference")
    }
    func testLargeTextServicesAndPassRemainReachable() {
        launch(largeText: true); shot("large-text-home")
        tap("home.service.Benefits"); XCTAssertTrue(element("service.start").waitForExistence(timeout: 5)); shot("large-text-service"); back()
        tap("home.memberPass"); XCTAssertTrue(element("pass.name").waitForExistence(timeout: 5)); shot("large-text-member-pass")
    }
    func testExistingAccountHelpHasWorkingBackNavigation() {
        launch(welcome: true); tap("welcome.access"); XCTAssertTrue(app.navigationBars["Reset access"].waitForExistence(timeout: 5))
        shot("02-account-access"); back(); XCTAssertTrue(element("welcome.name").waitForExistence(timeout: 5))
    }
}
