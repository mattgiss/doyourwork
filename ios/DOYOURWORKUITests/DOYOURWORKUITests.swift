import XCTest

/// Drives the real app in a simulator: setting a family up from nothing, a player's day from
/// picking chores to submitting, the bonus round, the save surviving a relaunch, and the admin
/// area. Screenshots are attached to the results.
///
/// The app is four pages swiped between, family · feed · chores · settings, under the heading
/// (docs/design/whiteboard-redesign.md). The same tests run on an iPhone (one page at a time) and
/// an iPad (the family on the left, the other pages on the right); the helpers below paper over
/// the difference in getting around.
///
/// Every launch passes `-uiTesting`, which gives the app a separate data folder. `-resetData`
/// starts from a fresh install; `-demoFamily` adds a family that's already set up (pat is the
/// admin, code 2468; riley and sam play); `-demoData` adds a made-up month of chores on top.
final class DOYOURWORKUITests: XCTestCase {
    private let wait: TimeInterval = 20
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private let adminCode = "2468"

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
        XCTAssertTrue(app.staticTexts["DOYOURWORK"].waitForExistence(timeout: wait))
        return app
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: wait))
        field.tap()
        field.typeText(text)
    }

    /// Waits until `condition` holds, polling, for up to `timeout` seconds.
    @discardableResult
    private func until(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }

    /// Whether `element` is there and can be tapped. While an alert is up nothing behind it can
    /// be, and asking XCTest then fails the test ("activation point invalid"), so don't ask.
    private func isOnScreen(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        let app = XCUIApplication()
        if element.elementType != .alert, app.alerts.firstMatch.exists { return false }
        // Off screen, or still sliding in or out, XCTest can't work out where to tap it and fails
        // the test for asking, so only ask about something inside the window.
        let frame = element.frame
        guard !frame.isEmpty, app.windows.firstMatch.frame.insetBy(dx: 1, dy: 1).contains(CGPoint(x: frame.midX, y: frame.midY)) else { return false }
        return element.isHittable
    }

    /// Leaves a person's profile (and the bonus picker inside it), back to the pages, by its back
    /// chevron. With no profile open there's nothing to do.
    private func closeProfile(in app: XCUIApplication) {
        let back = app.buttons["back"]
        let feed = app.buttons["page-feed"]
        // A relaunch brings back the profile that was open, and it can still be sliding in when
        // this runs, so go by what's on screen for a while, not by one look.
        let deadline = Date().addingTimeInterval(wait)
        var tries = 0
        while Date() < deadline {
            let backShown = isOnScreen(back)
            if !backShown, isOnScreen(feed) { return }
            if backShown, tries < 5 { back.tap(); tries += 1 }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    /// Whether the app is showing the family pane beside the other pages (an iPad app given a wide
    /// window): then the tab bar has no "family", since the family is always on the left.
    private func showsTwoPanes(_ app: XCUIApplication) -> Bool {
        closeProfile(in: app)
        XCTAssertTrue(app.buttons["page-feed"].waitForExistence(timeout: wait), "the tab bar should be along the bottom")
        return !app.buttons["page-family"].exists
    }

    /// Goes to one of the pages (family, feed, settings) by its button in the tab bar, closing a
    /// profile first if one is open. With two panes the family is always on the left, so there's
    /// nothing to tap for it.
    private func go(to page: String, in app: XCUIApplication) {
        if showsTwoPanes(app), page == "family" { return }
        let name = app.buttons["page-\(page)"]
        XCTAssertTrue(name.waitForExistence(timeout: wait), "the \(page) page should be there")
        // On a slow simulator a tap while a page is still sliding can be lost: tap again.
        for _ in 0..<3 where !name.isSelected {
            if name.isHittable { name.tap() }
            until(3) { name.isSelected }
        }
        XCTAssertTrue(name.isSelected, "the \(page) page should open")
        Thread.sleep(forTimeInterval: 0.4)   // let the page finish sliding in
    }

    /// Scrolls the page until `element` is on screen. It may not exist until it's scrolled near:
    /// grids only make what's close to being shown.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 3)
        // Short drags, a fifth of the screen each, so nothing is skipped past or left under the
        // heading or the tab bar between looks.
        // Drag in the element's own column: with two panes the middle of the screen is the gap
        // (or the fold) between them, and nothing scrolls there.
        // Until a grid makes the element, go by the tab bar, which sits under the pages' pane.
        func column() -> CGFloat {
            let width = app.frame.width
            guard width > 0 else { return 0.5 }
            for guide in [element, app.buttons["page-feed"]] where guide.exists && !guide.frame.isEmpty {
                return min(max(guide.frame.midX / width, 0.05), 0.95)
            }
            return 0.5
        }
        func drag(up: Bool) {
            let x = column()
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: up ? 0.6 : 0.4))
            let to = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: up ? 0.4 : 0.6))
            from.press(forDuration: 0.05, thenDragTo: to)
            Thread.sleep(forTimeInterval: 0.4)
        }
        for _ in 0..<15 where !isOnScreen(element) { drag(up: true) }
        for _ in 0..<15 where !isOnScreen(element) { drag(up: false) }
        // A page that's still sliding in, or redrawing after a change of look, settles in a moment.
        XCTAssertTrue(until(3) { self.isOnScreen(element) }, "\(element) should scroll into view")
    }

    /// Opens the admin area from the settings page, without unlocking it. On a slow simulator the
    /// tap on Admin, right after the page slides in, can be lost, so tap again while the code field
    /// hasn't shown up.
    private func openAdmin(in app: XCUIApplication) {
        go(to: "settings", in: app)
        let admin = app.buttons["admin"]
        let field = app.secureTextFields.firstMatch
        for _ in 0..<3 where !field.exists {
            reveal(admin, in: app)
            if admin.isHittable { admin.tap() }
            _ = field.waitForExistence(timeout: wait / 3)
        }
        XCTAssertTrue(field.exists, "Admin should open the code screen")
    }

    /// Opens the admin area and unlocks it.
    private func unlockAdmin(in app: XCUIApplication, code: String? = nil) {
        openAdmin(in: app)
        let field = app.secureTextFields.firstMatch
        type(code ?? adminCode, into: field)
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: wait), "the right code opens the admin area")
    }

    /// Opens one of the admin tabs. On a slow simulator the first tap, right as the sheet opens,
    /// can be lost, so tap again until the tab is selected.
    private func adminSection(_ name: String, in app: XCUIApplication) {
        let tab = app.segmentedControls.firstMatch.buttons[name.prefix(1).uppercased() + name.dropFirst()]
        XCTAssertTrue(tab.waitForExistence(timeout: wait))
        for _ in 0..<5 where !tab.isSelected {
            tab.tap()
            let until = Date().addingTimeInterval(2)
            while !tab.isSelected, Date() < until { Thread.sleep(forTimeInterval: 0.25) }
        }
        XCTAssertTrue(tab.isSelected, "the \(name) tab should open")
    }

    /// Saves the backup in the system's save panel under a name of its own and waits for the app to
    /// say it was saved. Returns how the file's name starts, to find it again. Replacing an earlier
    /// file with the same name can hang the simulator's Files.
    @discardableResult
    private func confirmBackupSave(in app: XCUIApplication) throws -> String {
        let saveButton = app.buttons["Save"]
        // iOS's own save panel, not the app: on CI's simulators it sometimes never shows its Save
        // button, or spins forever after it. Skip rather than fail on what the app can't control.
        guard saveButton.waitForExistence(timeout: wait) else { throw XCTSkip("iOS's own save panel didn't finish on this simulator; backups are covered by BackupTests") }
        let day = DateFormatter(); day.locale = Locale(identifier: "en_US_POSIX"); day.dateFormat = "yyyy-MM-dd"
        // Today's backups all start with this; the field gets a random ending on top so this save
        // doesn't replace an earlier one. On a slow simulator the typing can lag or be lost, so the
        // file is found again by this start, not the full name.
        let name = "doyourwork-backup-\(day.string(from: Date()))"
        let field = app.textFields["DOCPicker.filenameTextField"]
        if field.waitForExistence(timeout: 5) {
            field.tap()
            let current = (field.value as? String) ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 5)
                           + name + "-" + UUID().uuidString.prefix(6).lowercased())
        }
        saveButton.tap()
        let saved = app.staticTexts["Backup saved. Keep it somewhere safe, like Files or iCloud Drive."]
        let replace = app.buttons["Replace"]
        // A tap that lands while the panel is still loading does nothing, so tap Save again while
        // the panel is still up.
        let deadline = Date().addingTimeInterval(wait * 2)
        var lastTap = Date()
        while Date() < deadline && !saved.exists {
            if replace.exists {
                replace.tap()
                lastTap = Date()
            } else if saveButton.exists, saveButton.isHittable, Date().timeIntervalSince(lastTap) > 3 {
                saveButton.tap()
                lastTap = Date()
            }
            _ = saved.waitForExistence(timeout: 1)
        }
        // Still on the panel: iOS never finished saving. Off it without the message: the app's fault.
        if !saved.exists, app.textFields["DOCPicker.filenameTextField"].exists { throw XCTSkip("iOS's own save panel didn't finish on this simulator; backups are covered by BackupTests") }
        XCTAssertTrue(saved.exists, "the app should say the backup was saved")
        return name
    }

    /// Flips a switch. Tapping the middle of a labelled switch lands on its label, which does nothing.
    private func flip(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: wait))
        let before = toggle.value as? String
        let inner = toggle.switches.firstMatch
        if inner.exists { inner.tap() } else { toggle.tap() }
        if (toggle.value as? String) == before {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        XCTAssertNotEqual(toggle.value as? String, before, "the switch should have flipped")
    }

    /// A full-screen picture for the App Store listing, named "store-…" so CI can tell these from
    /// the other screenshots.
    private func storeScreenshot(_ name: String, of app: XCUIApplication) {
        Thread.sleep(forTimeInterval: 1.5)   // let screens finish sliding in and progress bars finish filling
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "store-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// A person's tile on the family page: their shown name, plus ", N-day streak" if they have one.
    private func playerTile(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tile-' AND (label == %@ OR label BEGINSWITH %@)", name, name + ", ")).firstMatch
    }

    /// A person's name where it can be tapped to rename them: on the chores page's header card, and
    /// on the settings page's profile card. Only the one on the page that's showing is on screen.
    private func nameButton(_ name: String, in app: XCUIApplication) -> XCUIElement? {
        app.buttons.matching(NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH 'tile-') AND NOT (identifier BEGINSWITH 'choose-')", name))
            .allElementsBoundByIndex.first { $0.isHittable }
    }

    /// One thing done on the feed: "riley load dishwasher", the time, and its verdict.
    private func feedItem(_ name: String, _ verdict: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@", name + " ", verdict)).firstMatch
    }

    /// `-demoData`'s month shows: on the feed, riley's approved chores and sam's waiting ones.
    private func assertDemoHistory(in app: XCUIApplication) {
        go(to: "feed", in: app)
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: wait), "the feed groups today's chores under Today")
        XCTAssertTrue(feedItem("riley", "approved", in: app).waitForExistence(timeout: wait), "riley's approved chores are on the feed")
        XCTAssertTrue(feedItem("sam", "waiting", in: app).exists, "sam's chores from today are waiting")
    }

    /// The big band button at the bottom of the picker and the card. The feed's dares button is the
    /// same kind of button, so rule that out.
    private func mainButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == 'main' AND NOT (label BEGINSWITH 'Make a dare')")).firstMatch
    }

    /// The puzzle's play button. The time left is on its own line ([timeLeft]).
    private func playButton(level: Int, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", "Clear the grid · level \(level)")).firstMatch
    }

    /// The "N minutes of games left today" line above the game buttons.
    private func timeLeft(minutes: Int, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "identifier == 'games-time-left' AND label BEGINSWITH %@", "\(minutes) minute")).firstMatch
    }

    private func uncheckedChores(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "value == 'not checked'"))
    }

    private func screenshot(_ name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func nudgeUp(_ app: XCUIApplication) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
        from.press(forDuration: 0.05, thenDragTo: to)
    }

    /// Checks off every chore on the card and returns the submit button, now enabled.
    private func checkOffEverything(in app: XCUIApplication) -> XCUIElement {
        let submit = app.buttons["Send it off for approval"]
        // Go by time, not a count of tries: on a slow simulator the card and the button can take
        // a while to settle, and a tap that lands mid-animation does nothing.
        let deadline = Date().addingTimeInterval(wait * 4)
        while !submit.exists, Date() < deadline {
            let next = uncheckedChores(in: app).firstMatch
            if next.exists, next.isHittable {
                next.tap()
            } else if !submit.waitForExistence(timeout: 1) {
                nudgeUp(app)
            }
        }
        XCTAssertTrue(submit.waitForExistence(timeout: wait), "checking every chore off should enable submit")
        XCTAssertTrue(submit.isEnabled)
        return submit
    }

    /// Opens a player's profile, with their day: goes to the family page (with two panes, an iPad
    /// app given a wide window, it's always on the left) and taps their tile. The profile has their
    /// name on its header card, beside a back chevron.
    private func open(_ name: String, in app: XCUIApplication) {
        go(to: "family", in: app)
        let tile = playerTile(name, in: app)
        XCTAssertTrue(tile.waitForExistence(timeout: wait), "\(name) should be on the family page")
        let back = app.buttons["back"]
        func opened() -> Bool { isOnScreen(back) && nameButton(name, in: app) != nil }
        // On a slow simulator the profile can trail the tap, and a tap that lands while the page
        // is still settling can be lost: wait, and tap again.
        for _ in 0..<3 where !opened() {
            if isOnScreen(tile) { tile.tap() }
            until(wait / 3, opened)
        }
        XCTAssertTrue(opened(), "\(name)'s profile should open")
    }

    /// Opens settings for a person: their profile's camera button ("Photo and border") goes to
    /// settings with them chosen.
    private func openSettings(for name: String, in app: XCUIApplication) {
        open(name, in: app)
        let look = app.buttons["edit-look"]
        XCTAssertTrue(look.waitForExistence(timeout: wait), "on a phone that isn't someone's, anyone's look can be changed")
        look.tap()
        let settings = app.buttons["page-settings"]
        XCTAssertTrue(until(wait) { settings.exists && settings.isSelected }, "Photo and border goes to settings")
        XCTAssertTrue(until(wait) { self.nameButton(name, in: app) != nil }, "settings shows \(name)")
    }

    /// Taps an alert's button once the alert has stopped moving, by its position. On CI's
    /// simulators XCTest sometimes can't work out where an alert button is ("activation point
    /// invalid"): `isHittable` then fails the test, and `tap()` treats the button as blocked and
    /// lets its own interruption handler press the alert's Cancel. A coordinate tap does neither.
    /// While the alert is still coming in, its button can report an infinite frame, so only a
    /// frame that's on screen counts, and the tap goes to where that frame was seen.
    private func tapWhenReady(_ button: XCUIElement, _ what: String) {
        XCTAssertTrue(button.waitForExistence(timeout: wait), "\(what) should appear")
        let app = XCUIApplication()
        var last = CGRect.null
        var settled = CGRect.null
        let deadline = Date().addingTimeInterval(wait)
        while Date() < deadline {
            let now = button.exists ? button.frame : .null
            let onScreen = !now.isEmpty && !now.isInfinite && app.frame.contains(CGPoint(x: now.midX, y: now.midY))
            if onScreen, now == last { settled = now; break }
            last = onScreen ? now : .null
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertFalse(settled.isNull, "\(what) should settle on screen")
        guard !settled.isNull else { return }
        // CI's simulators sometimes drop a synthesized tap on an alert outright: the alert stays,
        // with the button never even highlighted. Tap again while the button's still there.
        for _ in 0..<3 {
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: settled.midX, dy: settled.midY)).tap()
            if button.waitForNonExistence(timeout: 3) { return }
        }
        XCTFail("\(what) should close its alert when tapped")
    }

    /// Taps a button once it's there: on a slow simulator one that appears after the last tap
    /// (the card's band button, once a suggestion is in) can take a moment.
    private func tapOnceThere(_ button: XCUIElement) {
        XCTAssertTrue(button.waitForExistence(timeout: wait), "\(button) should appear")
        _ = until(wait) { button.isHittable }
        button.tap()
    }

    /// Steps back once: out of the admin area, out of the bonus picker, or out of a profile.
    private func goBack(in app: XCUIApplication) {
        let back = app.buttons.matching(NSPredicate(format: "label == 'Back'")).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(back, "there should be a way back")
        back?.tap()
        Thread.sleep(forTimeInterval: 0.6)   // let it slide away
    }

    // MARK: Tests

    func testADayFromPickingToSubmitting() {
        let app = launch(["-resetData", "-demoFamily"])

        // Family: both players, and nobody has a streak yet.
        go(to: "family", in: app)
        XCTAssertTrue(playerTile("riley", in: app).waitForExistence(timeout: wait))
        XCTAssertEqual(playerTile("riley", in: app).label, "riley, 0-day streak")
        XCTAssertEqual(playerTile("sam", in: app).label, "sam, 0-day streak")
        screenshot("01-home-empty", of: app)
        // Feed: nothing done yet.
        go(to: "feed", in: app)
        XCTAssertTrue(app.staticTexts["Nothing done yet this week. Chores show up here as they're sent in."].waitForExistence(timeout: wait))

        // Picker: nothing picked, so the card can't be locked in yet.
        open("riley", in: app)
        let main = mainButton(in: app)
        XCTAssertTrue(main.waitForExistence(timeout: wait))
        XCTAssertEqual(main.label, "Pick some chores, or let me suggest some")
        XCTAssertFalse(main.isEnabled)
        XCTAssertTrue(app.staticTexts["0 of 25 minutes"].exists)
        screenshot("02-picker-empty", of: app)

        // Suggest a full card, then lock it in.
        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        XCTAssertEqual(main.label, "Lock in my card")
        XCTAssertTrue(main.isEnabled)
        XCTAssertFalse(app.staticTexts["0 of 25 minutes"].exists, "the suggestion added minutes")
        screenshot("03-picker-suggested", of: app)
        main.tap()

        // Card: submit stays off until every chore is checked.
        XCTAssertTrue(app.buttons["Check everything off first"].waitForExistence(timeout: wait))
        XCTAssertFalse(mainButton(in: app).isEnabled)
        XCTAssertGreaterThan(uncheckedChores(in: app).count, 0)
        screenshot("04-card-unchecked", of: app)

        let submit = checkOffEverything(in: app)
        screenshot("05-card-checked", of: app)

        submit.tap()
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 0, "a submitted card can't be unchecked")
        screenshot("06-card-submitted", of: app)

        // Bonus round: one extra chore, logged straight to pending.
        app.buttons["Do a bonus round"].tap()
        XCTAssertTrue(app.buttons["Pick the chores you did"].waitForExistence(timeout: wait))
        uncheckedChores(in: app).firstMatch.tap()
        let logOne = app.buttons["Log this chore"]
        XCTAssertTrue(logOne.waitForExistence(timeout: wait))
        screenshot("07-bonus-picker", of: app)
        logOne.tap()
        XCTAssertTrue(app.staticTexts["Bonus round"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].exists)
        screenshot("08-card-with-bonus", of: app)

        // Relaunch: the day is still there.
        app.terminate()
        let relaunched = launch()
        open("riley", in: relaunched)
        XCTAssertTrue(relaunched.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        XCTAssertTrue(relaunched.staticTexts["Bonus round"].exists)

        // The other player's day is untouched.
        goBack(in: relaunched)
        open("sam", in: relaunched)
        XCTAssertTrue(relaunched.buttons["Pick some chores, or let me suggest some"].waitForExistence(timeout: wait))
    }

    func testAdminGateAndApprovals() {
        let app = launch(["-resetData", "-demoData"])
        let code = app.secureTextFields.firstMatch

        // A wrong code gets nowhere.
        openAdmin(in: app)
        type("definitely-not-it", into: code)
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.staticTexts["That code didn't match. Try again?"].waitForExistence(timeout: wait))
        XCTAssertEqual(app.segmentedControls.count, 0, "a wrong code must not reach the approvals")
        XCTAssertFalse(app.buttons["Approve this chore"].exists)
        screenshot("09-admin-wrong-code", of: app)

        // The admin's code opens it: sam's chores from today are waiting.
        type(adminCode, into: code)
        app.buttons["Unlock"].tap()
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: wait))
        let approve = app.buttons["Approve this chore"].firstMatch
        XCTAssertTrue(approve.waitForExistence(timeout: wait))
        screenshot("09b-admin-approvals", of: app)
        var approved = 0
        // Each row redraws as it's judged, so give the next one a moment to appear.
        while approve.waitForExistence(timeout: 2), approved < 30 { approve.tap(); approved += 1 }
        XCTAssertGreaterThan(approved, 0)
        XCTAssertTrue(app.staticTexts["Nothing's waiting for you. All caught up!"].waitForExistence(timeout: wait))

        // Back on sam's card, everything reads approved.
        goBack(in: app)
        open("sam", in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))
    }

    /// The admin's code box is ready to type into as soon as the lock screen opens, and a day's
    /// worth of one person's chores is approved with one tap.
    func testApproveAllOfADayInOneTap() {
        let app = launch(["-resetData", "-demoData"])
        openAdmin(in: app)
        // No tap on the field first: it already has the keyboard.
        app.typeText(adminCode + "\n")
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: wait), "the code typed straight away should unlock")
        let all = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Approve all'")).firstMatch
        XCTAssertTrue(all.waitForExistence(timeout: wait), "sam has several chores waiting: there should be an approve-all")
        screenshot("09c-approve-all", of: app)
        all.tap()
        XCTAssertTrue(app.staticTexts["Nothing's waiting for you. All caught up!"].waitForExistence(timeout: wait))
    }

    /// A backup saved to Files brings the whole scoreboard back after erasing everything.
    func testBackupSurvivesErasingEverything() throws {
        let app = launch(["-resetData", "-demoData"])
        assertDemoHistory(in: app)
        unlockAdmin(in: app)
        adminSection("device", in: app)

        // Save: the system's save panel, into "On My iPhone/iPad".
        let save = app.buttons["save-backup"]
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        save.tap()
        guard app.buttons["Save"].waitForExistence(timeout: wait) else { throw XCTSkip("iOS's own save panel didn't finish on this simulator; backups are covered by BackupTests") }
        screenshot("31-backup-save-panel", of: app)
        let backupName = try confirmBackupSave(in: app)
        XCTAssertTrue(app.buttons["OK"].waitForExistence(timeout: wait))
        tapWhenReady(app.buttons["OK"], "the saved message's OK")

        // Erase, then restore from the first screen, as a new phone would.
        let erase = app.buttons["Erase everything…"]
        XCTAssertTrue(erase.waitForExistence(timeout: wait))
        erase.tap()
        app.buttons["Erase players, chores and points"].tap()
        let restore = app.buttons["restore-backup"]
        XCTAssertTrue(restore.waitForExistence(timeout: wait), "setup offers restoring a backup")
        restore.tap()
        // This test's file by name: the simulator can hold backups from other tests and earlier runs.
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", backupName)).firstMatch
        // Older iOS opens the picker on Recents, which may not list the file yet: go to where it was saved.
        if !file.waitForExistence(timeout: 5) {
            for place in ["Browse", "On My iPhone", "On My iPad"] {
                let control = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND (elementType == %d OR elementType == %d OR elementType == %d)",
                                                                                   place, XCUIElement.ElementType.button.rawValue,
                                                                                   XCUIElement.ElementType.cell.rawValue, XCUIElement.ElementType.staticText.rawValue)).firstMatch
                if control.waitForExistence(timeout: 3) { control.tap() }
                if file.waitForExistence(timeout: 3) { break }
            }
        }
        guard file.waitForExistence(timeout: wait) else {
            throw XCTSkip("iOS's own file picker didn't list the backup on this simulator; restore is covered by BackupTests")
        }
        // Tap the file itself: on older iOS a tap on its name label (in the grid view) doesn't open it.
        let cell = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", backupName)).firstMatch
        if cell.exists { cell.tap() } else { file.tap() }
        let confirm = app.buttons["Replace everything here"]
        // Older iOS can select the file without opening it: open it.
        if !confirm.waitForExistence(timeout: 5) {
            let open = app.buttons["Open"]
            if open.waitForExistence(timeout: 3) { open.tap() }
            else if file.exists { file.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: -60)).tap() }
        }
        // On some simulators (CI's), iOS's own file picker ignores taps from UI tests: the file is on
        // screen but never opens. Restoring itself is covered by BackupTests in DoYourWorkCore.
        guard confirm.waitForExistence(timeout: wait) else {
            throw XCTSkip("the system file picker didn't open the backup on this simulator; restore is covered by BackupTests")
        }
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '2 players, 27 chores'")).firstMatch.exists)
        screenshot("32-backup-restore-confirm", of: app)
        tapWhenReady(confirm, "the restore confirmation")

        // Everything's back: the month of history, and the admin's code.
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Restored:'")).firstMatch.waitForExistence(timeout: wait))
        tapWhenReady(app.buttons["OK"], "the restored message's OK")
        assertDemoHistory(in: app)
        go(to: "family", in: app)
        XCTAssertTrue(playerTile("riley", in: app).waitForExistence(timeout: wait))
        unlockAdmin(in: app)

        // Restoring over a scoreboard that's set up, from the admin area: it says so, and the
        // admin area stays open with the scoreboard intact.
        adminSection("device", in: app)
        let again = app.buttons["restore-backup"]
        XCTAssertTrue(again.waitForExistence(timeout: wait))
        again.tap()
        XCTAssertTrue(file.waitForExistence(timeout: wait))
        file.tap()
        let replaceHere = app.buttons["Replace everything here"]
        XCTAssertTrue(replaceHere.waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'replaced by it'")).firstMatch.exists,
                      "over an existing scoreboard the confirmation warns it will be replaced")
        tapWhenReady(replaceHere, "Replace everything here")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Restored:'")).firstMatch.waitForExistence(timeout: wait))
        tapWhenReady(app.buttons["OK"], "the restored message's OK")
        goBack(in: app)
        assertDemoHistory(in: app)
    }

    /// From a fresh install to a working scoreboard, with chores written in the family's own words.
    func testSettingUpFromNothing() {
        let app = launch(["-resetData"])

        // No players are built in: a fresh install starts with the welcome.
        let start = app.buttons["Set up this device"]
        XCTAssertTrue(start.waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Everything stays on this device."].exists)
        XCTAssertTrue(app.staticTexts["No accounts, no sign-in, no ads, no tracking."].exists)
        XCTAssertFalse(app.buttons["admin"].exists)
        screenshot("20-setup-welcome", of: app)
        start.tap()

        // Who's in charge: a name and a code typed twice.
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled)
        type("pat", into: app.textFields["admin-name"])
        type("2468", into: app.secureTextFields["admin-code"])
        type("246", into: app.secureTextFields["admin-code-again"])
        XCTAssertTrue(app.staticTexts["Those two codes don't match."].waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled)
        app.secureTextFields["admin-code-again"].typeText("8\n")
        XCTAssertFalse(app.staticTexts["Those two codes don't match."].exists)
        XCTAssertTrue(next.isEnabled)
        screenshot("21-setup-admin", of: app)
        next.tap()

        // Who's playing: one added with the button, one left in the box.
        XCTAssertTrue(app.staticTexts["Who's playing?"].waitForExistence(timeout: wait))
        XCTAssertFalse(next.isEnabled, "someone has to play")
        type("riley\n", into: app.textFields["player-name"])
        XCTAssertTrue(app.staticTexts["riley"].waitForExistence(timeout: wait))
        type("sam", into: app.textFields["player-name"])
        screenshot("22-setup-players", of: app)
        next.tap()

        // What needs doing: said in a sentence, sorted into a list.
        let own = app.buttons["Write or say your own"]
        XCTAssertTrue(own.waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons["Use the starter list"].exists)
        own.tap()
        type("We need to do the dishes and take out the trash, someone has to feed the dog for 5 minutes. Water plants", into: app.textViews["chore-text"])
        screenshot("23-setup-chores-written", of: app)
        app.buttons["Sort into chores"].tap()
        XCTAssertTrue(app.buttons["Add 4 chores"].waitForExistence(timeout: wait))
        for name in ["do the dishes", "take out the trash", "feed the dog", "water plants"] {
            XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", name)).firstMatch.exists, "\(name) should be on the list")
        }
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == '5m'")).firstMatch.exists, "the time that was mentioned is kept")
        screenshot("24-setup-chores-sorted", of: app)
        app.buttons["Leave out water plants"].tap()
        let add = app.buttons["Add 3 chores"]
        XCTAssertTrue(add.waitForExistence(timeout: wait))
        add.tap()

        // The family: the two players, and not the admin, who doesn't do chores.
        XCTAssertTrue(playerTile("riley", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(playerTile("sam", in: app).exists)
        XCTAssertFalse(playerTile("pat", in: app).exists)
        screenshot("25-setup-done", of: app)

        // Their own three chores are what there is to pick, at their normal times: nothing starts overdue.
        open("riley", in: app)
        XCTAssertTrue(mainButton(in: app).waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 3)
        XCTAssertTrue(app.staticTexts["feed the dog"].exists || app.descendants(matching: .any)["feed the dog"].exists)
        XCTAssertFalse(app.staticTexts["!!"].exists)
        screenshot("26-own-chores-picker", of: app)
        goBack(in: app)

        // It's all still there after a restart, and the code chosen at setup opens the admin area.
        app.terminate()
        let relaunched = launch()
        go(to: "family", in: relaunched)
        XCTAssertTrue(playerTile("sam", in: relaunched).waitForExistence(timeout: wait))
        XCTAssertFalse(relaunched.buttons["Set up this device"].exists)
        unlockAdmin(in: relaunched)
        goBack(in: relaunched)
    }

    /// Admins add players, hand out admin rights and change the chore list.
    func testAdminsChangePlayersAndChores() {
        let app = launch(["-resetData", "-demoFamily"])
        unlockAdmin(in: app)

        // Add a player.
        adminSection("players", in: app)
        app.buttons["+ add player"].tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        XCTAssertFalse(save.isEnabled, "a player needs a name")
        type("sam", into: app.textFields["member-name"])
        XCTAssertTrue(app.staticTexts["Someone already has that name."].waitForExistence(timeout: wait))
        XCTAssertFalse(save.isEnabled)
        app.textFields["member-name"].typeText("antha")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["Edit samantha"].waitForExistence(timeout: wait))

        // Make her an admin: that needs a code of her own.
        app.buttons["Edit samantha"].tap()
        flip(app.switches["Admin"])
        XCTAssertFalse(save.isEnabled, "an admin needs a code")
        type("1357", into: app.secureTextFields["member-code"])
        XCTAssertTrue(save.isEnabled)
        screenshot("27-admin-edit-player", of: app)
        save.tap()
        XCTAssertTrue(app.buttons["Edit samantha"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Admin · not playing"].exists, "pat runs the scoreboard without doing chores")
        screenshot("28-admin-players", of: app)

        // The last admin can't be removed, but a player can.
        app.buttons["Edit pat"].tap()
        XCTAssertTrue(save.waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Remove pat'")).firstMatch.exists, "with two admins, either can go")
        app.buttons["Cancel"].tap()

        // Add a chore in plain words, then find it on the list.
        adminSection("chores", in: app)
        app.buttons["+ add chores"].tap()
        type("feed the fish 2 minutes, make bed", into: app.textViews["chore-text"])
        app.buttons["Sort into chores"].tap()
        let add = app.buttons["Add 1 chore"]
        XCTAssertTrue(add.waitForExistence(timeout: wait), "make bed is already on the list, so only the fish is new")
        add.tap()
        XCTAssertTrue(app.buttons["Edit feed the fish"].waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["28 chores. left undone, a chore takes longer the next time it's picked."].exists)
        screenshot("29-admin-chores", of: app)

        // Out on the family page: the new player is there, and her code opens the admin area too.
        goBack(in: app)
        go(to: "family", in: app)
        XCTAssertTrue(playerTile("samantha", in: app).waitForExistence(timeout: wait))
        unlockAdmin(in: app, code: "1357")
        goBack(in: app)
    }

    /// Everything the app holds can be wiped from inside it.
    func testEraseEverythingStartsOver() throws {
        let app = launch(["-resetData", "-demoData"])
        assertDemoHistory(in: app)
        unlockAdmin(in: app)
        adminSection("device", in: app)
        XCTAssertTrue(app.staticTexts["Your data"].waitForExistence(timeout: wait))
        screenshot("30-admin-device", of: app)
        app.buttons["Erase everything…"].tap()
        let confirm = app.buttons["Erase players, chores and points"]
        XCTAssertTrue(confirm.waitForExistence(timeout: wait))
        confirm.tap()

        // Back to a fresh install, and it stays that way after a restart.
        XCTAssertTrue(app.buttons["Set up this device"].waitForExistence(timeout: wait))
        XCTAssertFalse(playerTile("riley", in: app).exists)
        app.terminate()
        let relaunched = launch()
        XCTAssertTrue(relaunched.buttons["Set up this device"].waitForExistence(timeout: wait))
        XCTAssertFalse(playerTile("riley", in: relaunched).exists)
        XCTAssertFalse(relaunched.buttons["page-feed"].exists, "no pages until it's set up again")
    }

    func testDemoHistoryShowsTheDailyLogAndVerdicts() {
        let app = launch(["-resetData", "-demoData"])

        // The family: the steady player is on a streak (they took every ninth day off, not today).
        go(to: "family", in: app)
        let riley = playerTile("riley", in: app)
        XCTAssertTrue(riley.waitForExistence(timeout: wait))
        XCTAssertTrue(riley.label.hasSuffix("-day streak") && riley.label != "riley, 0-day streak", riley.label)
        screenshot("10-home-with-history", of: app)

        // The feed: this week's chores, newest first, with their verdicts.
        assertDemoHistory(in: app)
        XCTAssertTrue(app.staticTexts["Yesterday"].exists, "earlier days get their own heading")
        screenshot("13-feed-with-history", of: app)

        // However far the feed is pushed, the heading stays where it is.
        let title = app.staticTexts["DOYOURWORK"]
        let before = title.frame
        feedItem("riley", "approved", in: app).swipeUp()
        XCTAssertEqual(title.frame, before, "the heading shouldn't scroll away")
        XCTAssertTrue(title.isHittable)
        screenshot("14-home-pushed-up", of: app)

        // The second player's chores for today are waiting on an admin.
        open("sam", in: app)
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        screenshot("11-card-awaiting", of: app)

        // The first player's are approved, and a month of approved chores levels you up.
        open("riley", in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))
        let version = app.staticTexts.matching(NSPredicate(format: "label CONTAINS ' this week'")).firstMatch
        XCTAssertTrue(version.exists)
        XCTAssertFalse(version.label.hasPrefix("v1.0 "), version.label)
        screenshot("12-card-approved", of: app)
    }

    /// A bug we shipped: chores were submitted under a player's name, a parent rejected them all, and
    /// the player was stuck — a card of ✗s, nothing left to pick, "already submitted" for the day.
    /// A rejected day isn't a finished day: they get the picker back and can submit a new card.
    func testARejectedDayStartsOver() {
        let app = launch(["-resetData", "-demoData", "-demoRejectedDay"])

        open("sam", in: app)
        let main = mainButton(in: app)
        XCTAssertTrue(main.waitForExistence(timeout: wait))
        XCTAssertEqual(main.label, "Pick some chores, or let me suggest some", "a day of rejections should offer the picker, not a finished card")
        XCTAssertTrue(app.staticTexts["Today's earlier chores were turned down, so let's build a new card."].exists)
        // The other player's six approved chores are spoken for today.
        XCTAssertTrue(app.staticTexts["Someone else already has 6 of today's chores."].exists)
        XCTAssertFalse(app.buttons["Do a bonus round"].exists)
        screenshot("15-rejected-day-picker", of: app)

        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        XCTAssertEqual(main.label, "Lock in my card")
        main.tap()
        checkOffEverything(in: app).tap()

        // The new card is in and waiting; nothing on it reads as rejected.
        let waiting = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'waiting for an admin'")).firstMatch
        XCTAssertTrue(waiting.waitForExistence(timeout: wait))
        XCTAssertEqual(uncheckedChores(in: app).count, 0)
        screenshot("16-rejected-day-resubmitted", of: app)

        // Someone else's day is untouched.
        goBack(in: app)
        open("riley", in: app)
        XCTAssertTrue(app.staticTexts["Everything's approved. Nice work!"].waitForExistence(timeout: wait))
    }

    /// Submitting today's card unlocks the puzzle. A move that isn't allowed changes nothing;
    /// clearing the board levels up, and the next level is remembered on the card.
    func testSubmittingUnlocksThePuzzleAndClearingLevelsUp() {
        let app = launch(["-resetData", "-demoFamily"])
        open("riley", in: app)
        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        mainButton(in: app).tap()

        // Locked until the card is in.
        XCTAssertTrue(app.staticTexts["The puzzle opens once you send your card."].waitForExistence(timeout: wait))
        XCTAssertFalse(playButton(level: 1, in: app).exists)
        checkOffEverything(in: app).tap()

        let play = playButton(level: 1, in: app)
        XCTAssertTrue(play.waitForExistence(timeout: wait), "a submitted card unlocks the puzzle")
        screenshot("puzzle-1-unlocked", of: app)
        play.tap()

        // Level 1 (native/puzzles.json), four wide:
        //   P K . .      cells 0 and 1
        //   . . . K      cell 7
        //   . . . .
        //   . . . .
        //   . . . P      cell 19
        func cell(_ i: Int) -> XCUIElement { app.descendants(matching: .any)["cell-\(i)"] }
        XCTAssertTrue(cell(0).waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["LVL 1"].exists)
        XCTAssertTrue(app.staticTexts["4 blocks left"].exists)
        screenshot("puzzle-2-level-1", of: app)

        // Pink 0 and black 7 aren't in line: nothing happens.
        cell(0).tap()
        XCTAssertTrue(app.staticTexts["Now tap a block of the other colour in line with it."].waitForExistence(timeout: wait))
        cell(7).tap()
        XCTAssertTrue(app.staticTexts["4 blocks left"].exists, "a move that isn't allowed removes nothing")

        // Black 7 straight down to pink 19.
        cell(7).tap()
        cell(19).tap()
        XCTAssertTrue(app.staticTexts["2 blocks left"].waitForExistence(timeout: wait))
        XCTAssertFalse(cell(7).exists)
        XCTAssertFalse(cell(19).exists)

        // The last pair clears the board: level up.
        cell(0).tap()
        cell(1).tap()
        let levelUp = app.descendants(matching: .any)["Level up"]
        XCTAssertTrue(levelUp.waitForExistence(timeout: wait), "clearing the board levels up")
        XCTAssertTrue(app.staticTexts["LVL 2"].exists)
        XCTAssertTrue(app.staticTexts["4 blocks cleared"].exists)
        let next = app.buttons["Next level"]
        XCTAssertTrue(next.waitForExistence(timeout: wait))
        screenshot("puzzle-3-level-up", of: app)
        next.tap()

        // Level 2 is up, and the card remembers it.
        XCTAssertTrue(app.staticTexts["LVL 2"].waitForExistence(timeout: wait))
        XCTAssertFalse(levelUp.exists)
        XCTAssertTrue(app.staticTexts["4 blocks left"].exists)
        screenshot("puzzle-4-level-2", of: app)
        app.buttons["puzzle-back"].tap()
        XCTAssertTrue(playButton(level: 2, in: app).waitForExistence(timeout: wait))
    }

    /// Submitting today's card unlocks snake too. A swipe starts it; running into the wall ends the
    /// game, and "Play again" starts a fresh one.
    func testSubmittingUnlocksSnake() {
        let app = launch(["-resetData", "-demoFamily"])
        open("riley", in: app)
        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        mainButton(in: app).tap()

        let snake = app.buttons["play-snake"]
        XCTAssertTrue(app.staticTexts["The puzzle opens once you send your card."].waitForExistence(timeout: wait))
        XCTAssertFalse(snake.exists, "locked until the card is in")
        checkOffEverything(in: app).tap()
        XCTAssertTrue(snake.waitForExistence(timeout: wait), "a submitted card unlocks snake")
        snake.tap()

        let board = app.descendants(matching: .any)["snake-board"]
        let score = app.staticTexts["snake-score"]
        XCTAssertTrue(board.waitForExistence(timeout: wait))
        XCTAssertEqual(score.label, "Score 0")
        screenshot("snake-1-ready", of: app)

        // The line starts in the middle of a 15 by 15 board; swiped up, it hits the top wall in eight steps.
        board.swipeUp()
        let over = app.staticTexts["snake-over"]
        XCTAssertTrue(over.waitForExistence(timeout: wait), "running into the wall ends the game")
        XCTAssertEqual(over.label, "Game over")
        screenshot("snake-2-game-over", of: app)

        app.buttons["Play again"].tap()
        XCTAssertTrue(over.waitForNonExistence(timeout: wait))
        XCTAssertEqual(score.label, "Score 0")
        app.buttons["snake-back"].tap()
        XCTAssertTrue(snake.waitForExistence(timeout: wait))
    }

    /// The games get 30 minutes a day per player. The play button counts down; when the time runs
    /// out mid-level the board is covered and only "back" works, and the day screen says so.
    func testThePuzzleStopsAfterAnHourADay() {
        let app = launch(["-resetData", "-demoFamily", "-puzzleSecondsLeft", "125"])
        open("riley", in: app)
        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        mainButton(in: app).tap()
        checkOffEverything(in: app).tap()
        let play = playButton(level: 1, in: app)
        XCTAssertTrue(play.waitForExistence(timeout: wait), "125 seconds left shows as 3 minutes")
        XCTAssertTrue(timeLeft(minutes: 3, in: app).exists, "125 seconds left shows as 3 minutes")
        app.terminate()

        // Down to the last few seconds: they run out while the board is up.
        let again = launch(["-puzzleSecondsLeft", "3"])
        open("riley", in: again)
        let last = playButton(level: 1, in: again)
        XCTAssertTrue(last.waitForExistence(timeout: wait))
        XCTAssertTrue(timeLeft(minutes: 1, in: again).exists)
        last.tap()
        XCTAssertTrue(again.descendants(matching: .any)["cell-0"].waitForExistence(timeout: wait))
        let covered = again.staticTexts["That's your 30 minutes of games for today. See you tomorrow!"]
        XCTAssertTrue(covered.waitForExistence(timeout: 10), "the board is covered when time runs out")
        screenshot("puzzle-time-up", of: again)
        again.buttons["puzzle-timeup-back"].tap()
        XCTAssertTrue(again.staticTexts["That's your 30 minutes of games for today. See you tomorrow!"].waitForExistence(timeout: wait))
        XCTAssertFalse(again.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Clear the grid'")).firstMatch.exists)
    }

    /// A display name is a nickname on top of the username: it shows everywhere the player does,
    /// survives a relaunch, and can be dropped again, leaving the username as it was.
    func testADisplayNameSitsOnTopOfTheUsername() {
        let app = launch(["-resetData", "-demoFamily"])
        let nickname = "xX_D1no_K1ng_Xx"

        // A player gives themselves a display name from their own day: no admin needed. Their
        // name on the header card is what's tapped.
        open("sam", in: app)
        nameButton("sam", in: app)?.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: wait), "tapping the name asks for a display name")
        XCTAssertTrue(app.alerts["Display name"].exists)
        field.typeText(nickname)
        app.alerts.buttons["Save"].tap()

        // It replaces the username wherever the player is shown…
        XCTAssertTrue(until(wait) { self.nameButton(nickname, in: app) != nil }, "the header card shows the new name")
        XCTAssertTrue(mainButton(in: app).waitForExistence(timeout: wait), "their day still opens as normal")
        go(to: "family", in: app)
        XCTAssertTrue(playerTile(nickname, in: app).waitForExistence(timeout: wait))
        XCTAssertFalse(playerTile("sam", in: app).exists)
        XCTAssertTrue(playerTile("riley", in: app).exists, "nobody else's name changes")
        screenshot("19-display-name", of: app)

        // …is still there after the app restarts…
        app.terminate()
        let relaunched = launch()
        go(to: "family", in: relaunched)
        XCTAssertTrue(playerTile(nickname, in: relaunched).waitForExistence(timeout: wait))

        // …and comes off again, from the name on the settings page's profile card, with the
        // username underneath untouched.
        openSettings(for: nickname, in: relaunched)
        nameButton(nickname, in: relaunched)?.tap()
        XCTAssertTrue(relaunched.alerts.buttons["Use my username"].waitForExistence(timeout: wait))
        relaunched.alerts.buttons["Use my username"].tap()
        XCTAssertTrue(until(wait) { self.nameButton("sam", in: relaunched) != nil }, "the profile card shows the username again")
        go(to: "family", in: relaunched)
        XCTAssertTrue(playerTile("sam", in: relaunched).waitForExistence(timeout: wait))
        XCTAssertFalse(playerTile(nickname, in: relaunched).exists)
    }

    /// Everyone has a character on their tile. A player picks their own from the settings page, it
    /// survives a relaunch, and nobody else can take it while it's theirs.
    func testAPlayerPicksTheirOwnCharacter() {
        let app = launch(["-resetData", "-demoFamily"])
        let robot = app.buttons["character-robot"]
        /// Opens the character picker on someone's settings.
        func pickCharacter(_ name: String, in app: XCUIApplication) {
            openSettings(for: name, in: app)
            let change = app.buttons["Change character"]
            reveal(change, in: app)
            change.tap()
            XCTAssertTrue(app.buttons["character-robot"].waitForExistence(timeout: wait), "the character picker should open")
        }

        // Sam starts with one given from their username, and swaps it for the robot.
        pickCharacter("sam", in: app)
        XCTAssertTrue(robot.isEnabled)
        XCTAssertFalse(robot.isSelected, "sam doesn't start as the robot")
        screenshot("20-pick-a-character", of: app)
        robot.tap()
        XCTAssertTrue(robot.waitForNonExistence(timeout: wait), "picking one closes the picker")
        pickCharacter("sam", in: app)
        XCTAssertTrue(robot.isSelected, "the robot is sam's now")
        app.buttons["Done"].tap()
        XCTAssertTrue(robot.waitForNonExistence(timeout: wait))

        // Riley sees the robot is Sam's and can't have it.
        pickCharacter("riley", in: app)
        XCTAssertFalse(robot.isEnabled, "the robot is sam's")
        XCTAssertEqual(robot.value as? String, "sam has this one")
        app.buttons["Done"].tap()
        XCTAssertTrue(robot.waitForNonExistence(timeout: wait))

        // Still Sam's after the app restarts.
        app.terminate()
        let relaunched = launch()
        pickCharacter("sam", in: relaunched)
        XCTAssertTrue(relaunched.buttons["character-robot"].isSelected)
    }

    /// A person picks a border to wear from the borders they've earned, on the settings page. One
    /// they haven't earned can't be picked. It's still theirs after a relaunch.
    func testAPlayerPicksABorder() {
        let app = launch(["-resetData", "-demoData"])
        func border(_ id: String, in app: XCUIApplication) -> XCUIElement { app.buttons["border-\(id)"] }

        // riley has a month of chores behind them (about 2700 points): the ring, the puppy and
        // hearts are theirs to wear, the halo (5000) isn't yet. Nothing's worn to begin with.
        openSettings(for: "riley", in: app)
        XCTAssertTrue(app.staticTexts["Borders"].waitForExistence(timeout: wait))
        XCTAssertTrue(border("none", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(border("none", in: app).isSelected, "no border until one is picked")
        reveal(border("ring", in: app), in: app)
        XCTAssertTrue(border("ring", in: app).isEnabled, "the ring is unlocked from 0 points")
        XCTAssertTrue(border("puppy", in: app).isEnabled, "the puppy unlocks at 50 points")
        reveal(border("hearts", in: app), in: app)
        XCTAssertTrue(border("hearts", in: app).isEnabled, "hearts unlock at 500 points")
        reveal(border("halo", in: app), in: app)
        XCTAssertFalse(border("halo", in: app).isEnabled, "the halo needs 5000 points")
        // The number is written the phone's way ("5,000" here), so only its shape is checked.
        let haloValue = border("halo", in: app).value as? String ?? ""
        XCTAssertTrue(haloValue.hasPrefix("unlocks at 5") && haloValue.hasSuffix("000 points"), haloValue)

        let hearts = border("hearts", in: app)
        reveal(hearts, in: app)
        hearts.tap()
        XCTAssertTrue(until(wait) { hearts.isSelected }, "the border tapped is the one worn")
        XCTAssertEqual(hearts.value as? String, "wearing")
        reveal(border("none", in: app), in: app)
        XCTAssertFalse(border("none", in: app).isSelected)
        XCTAssertFalse(border("ring", in: app).isSelected)
        screenshot("21-pick-a-border", of: app)

        // A locked one does nothing.
        let halo = border("halo", in: app)
        reveal(halo, in: app)
        halo.tap()
        XCTAssertFalse(halo.isSelected)
        reveal(hearts, in: app)
        XCTAssertTrue(hearts.isSelected, "a locked border can't be picked")

        // Still worn after the app restarts.
        app.terminate()
        let relaunched = launch()
        openSettings(for: "riley", in: relaunched)
        reveal(border("hearts", in: relaunched), in: relaunched)
        XCTAssertTrue(border("hearts", in: relaunched).isSelected)
    }

    /// One chore, one person, per day — including when two players go for the same chores at once.
    func testAChoreCanOnlyBeOnePersonsEachDay() {
        let app = launch(["-resetData", "-demoFamily"])

        // sam builds a card but doesn't submit it yet.
        open("sam", in: app)
        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        tapOnceThere(app.buttons["Lock in my card"])
        XCTAssertTrue(app.buttons["Check everything off first"].waitForExistence(timeout: wait))
        let onCard = uncheckedChores(in: app).count
        XCTAssertGreaterThan(onCard, 0)

        // riley is offered the same suggestion, takes it, and gets it in first.
        goBack(in: app)
        open("riley", in: app)
        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        tapOnceThere(app.buttons["Lock in my card"])
        checkOffEverything(in: app).tap()
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))

        // Back on sam's card every chore now reads as taken, and it can't be submitted.
        goBack(in: app)
        open("sam", in: app)
        let blocked = app.buttons["Everything's been taken today. Change your picks"]
        XCTAssertTrue(blocked.waitForExistence(timeout: wait))
        XCTAssertFalse(blocked.isEnabled)
        XCTAssertEqual(uncheckedChores(in: app).count, 0, "taken chores can't be checked off")
        XCTAssertTrue(app.staticTexts["Someone else got to the ones marked taken first, so they won't be sent."].exists)
        screenshot("17-card-all-taken", of: app)

        // Picking again offers only what's left, and that card goes in.
        app.buttons["Change my picks"].tap()
        let taken = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Someone else already has'")).firstMatch
        XCTAssertTrue(taken.waitForExistence(timeout: wait))
        XCTAssertTrue(taken.label.contains(onCard == 1 ? "has one of" : "has \(onCard) of"), taken.label)
        screenshot("18-picker-with-taken", of: app)
        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        tapOnceThere(app.buttons["Lock in my card"])
        checkOffEverything(in: app).tap()
        XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
    }

    /// Takes the six pictures for the App Store listing, with `-screenshots`' made-up family. CI
    /// runs this on the simulators whose screens match the sizes App Store Connect asks for and
    /// uploads the results (see ios/AppStore/SUBMISSION.md).
    func testAppStoreScreenshots() {
        // 2. A fresh install: what the app is and what it doesn't do with your data.
        let fresh = launch(["-resetData", "-screenshots"])
        XCTAssertTrue(fresh.buttons["Set up this device"].waitForExistence(timeout: wait))
        storeScreenshot("02-private-by-design", of: fresh)
        fresh.terminate()

        // 1. The family: everyone's tile, with their streaks.
        let app = launch(["-resetData", "-demoData", "-screenshots"])
        go(to: "family", in: app)
        XCTAssertTrue(playerTile("sockninja", in: app).waitForExistence(timeout: wait))
        if showsTwoPanes(app) {
            // The right-hand side would only ask who's doing chores: show a day waiting on an admin.
            open("dishwizard", in: app)
            XCTAssertTrue(app.staticTexts["Sent! Now it's waiting for an admin to look at it."].waitForExistence(timeout: wait))
        }
        storeScreenshot("01-scoreboard", of: app)

        // 3. Picking today's chores, with a suggested card.
        open("broomrider", in: app)
        let main = mainButton(in: app)
        XCTAssertTrue(main.waitForExistence(timeout: wait))
        tapOnceThere(app.buttons["Suggest a 25-minute card"])
        XCTAssertEqual(main.label, "Lock in my card")
        storeScreenshot("03-pick-chores", of: app)

        // 4. The card, partly checked off.
        main.tap()
        XCTAssertTrue(app.buttons["Check everything off first"].waitForExistence(timeout: wait))
        for _ in 0..<2 {
            let next = uncheckedChores(in: app).firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: wait))
            next.tap()
        }
        storeScreenshot("04-todays-card", of: app)

        // 6. The admin area (from settings), with today's chores waiting for a yes or no.
        unlockAdmin(in: app)
        XCTAssertTrue(app.buttons["Approve this chore"].firstMatch.waitForExistence(timeout: wait))
        storeScreenshot("06-approvals", of: app)

        // 5. A household's own chores, said in a sentence and sorted into a list.
        adminSection("chores", in: app)
        app.buttons["+ add chores"].tap()
        type("Wash the car, walk the dog for 15 minutes, feed the fish and tidy the playroom. Clean out the fridge", into: app.textViews["chore-text"])
        app.buttons["Sort into chores"].tap()
        XCTAssertTrue(app.buttons["Add 5 chores"].waitForExistence(timeout: wait))
        storeScreenshot("05-your-own-chores", of: app)
    }

    func testIPadShowsTheListAndTheDaySideBySide() throws {
        try XCTSkipUnless(isPad, "two panes are the iPad layout")
        let app = launch(["-resetData", "-demoData"])
        try XCTSkipUnless(showsTwoPanes(app), "the app's window is too narrow for two panes; give it the whole screen")
        let sent = app.staticTexts["Sent! Now it's waiting for an admin to look at it."]
        let approved = app.staticTexts["Everything's approved. Nice work!"]

        // Nothing picked yet: the family on the left, the feed on the right. Only the right-hand
        // pages are in the tab bar.
        XCTAssertTrue(feedItem("riley", "approved", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(isOnScreen(playerTile("riley", in: app)))
        XCTAssertFalse(app.buttons["page-family"].exists, "the family is always on screen, so it isn't in the tab bar")
        XCTAssertTrue(app.buttons["page-feed"].isSelected)
        screenshot("ipad-01-nothing-picked", of: app)

        // A player's profile opens on the right; the family stays, with that player highlighted.
        open("sam", in: app)
        XCTAssertTrue(sent.waitForExistence(timeout: wait))
        XCTAssertTrue(isOnScreen(playerTile("riley", in: app)), "the family stays on screen")
        XCTAssertTrue(playerTile("sam", in: app).isSelected)
        XCTAssertLessThan(playerTile("sam", in: app).frame.maxX, sent.frame.minX, "the day sits to the right of the family, not over it")
        screenshot("ipad-02-day-beside-list", of: app)

        // Picking someone else swaps the right-hand side.
        open("riley", in: app)
        XCTAssertTrue(approved.waitForExistence(timeout: wait))
        XCTAssertTrue(playerTile("riley", in: app).isSelected)
        XCTAssertFalse(playerTile("sam", in: app).isSelected)

        // The bonus picker has its own way back, to the day.
        app.buttons["Do a bonus round"].tap()
        XCTAssertTrue(app.buttons["Pick the chores you did"].waitForExistence(timeout: wait))
        goBack(in: app)
        XCTAssertTrue(approved.waitForExistence(timeout: wait))

        // Leaving the profile brings back the pages on the right; the family stays.
        goBack(in: app)
        XCTAssertTrue(until(wait) { self.isOnScreen(app.buttons["page-feed"]) }, "the right-hand pages come back")
        XCTAssertTrue(isOnScreen(playerTile("riley", in: app)))
        XCTAssertFalse(playerTile("riley", in: app).isSelected, "nobody's highlighted with no profile open")

        // The admin area opens from settings, over everything, and closing it returns there.
        openAdmin(in: app)
        screenshot("ipad-03-admin-area", of: app)
        goBack(in: app)
        XCTAssertTrue(until(wait) { app.buttons["page-settings"].isSelected })
        XCTAssertTrue(isOnScreen(playerTile("riley", in: app)))

        // Turned sideways it's still two panes on the same screen.
        open("riley", in: app)
        XCTAssertTrue(approved.waitForExistence(timeout: wait))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(approved.waitForExistence(timeout: wait))
        XCTAssertTrue(until(wait) { let f = app.windows.firstMatch.frame; return f.width > f.height }, "the app should have turned with the iPad")
        XCTAssertTrue(playerTile("riley", in: app).isSelected)
        XCTAssertLessThan(playerTile("riley", in: app).frame.maxX, approved.frame.minX)
        // The whole screen, not the app's own snapshot, which comes back cropped when sideways.
        let sideways = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        sideways.name = "ipad-04-landscape"
        sideways.lifetime = .keepAlways
        add(sideways)
        XCUIDevice.shared.orientation = .portrait
    }

    /// Dark, light or glass is picked in settings. Each one redraws the whole app; afterwards the
    /// app still works, starting with the family's tiles. Put back to dark at the end, since the
    /// choice is kept on the phone (and `-resetData` doesn't clear it).
    func testSwitchingAppearanceKeepsTheAppWorking() {
        let app = launch(["-resetData", "-demoFamily"])
        func mode(_ name: String) -> XCUIElement { app.buttons["appearance-\(name)"] }
        /// Taps a mode in settings' Look card and waits for the redrawn app to show it picked.
        func pick(_ name: String) {
            go(to: "settings", in: app)
            reveal(mode(name), in: app)
            mode(name).tap()
            XCTAssertTrue(until(wait) { mode(name).exists && mode(name).isSelected }, "\(name) should be the one picked")
            Thread.sleep(forTimeInterval: 1)   // the whole app redraws
            XCTAssertTrue(until(wait) { app.buttons["page-settings"].exists && app.buttons["page-settings"].isSelected }, "still on settings after redrawing")
        }
        func familyStillWorks(_ name: String) {
            go(to: "family", in: app)
            XCTAssertTrue(until(wait) { self.isOnScreen(self.playerTile("riley", in: app)) }, "the family's tiles are there in \(name)")
            XCTAssertTrue(isOnScreen(playerTile("sam", in: app)))
            screenshot("50-appearance-\(name)", of: app)
        }
        defer {
            // Leave the phone the way it was, even when a check above failed.
            go(to: "settings", in: app)
            if mode("dark").exists, !mode("dark").isSelected { reveal(mode("dark"), in: app); mode("dark").tap() }
        }

        go(to: "settings", in: app)
        reveal(mode("dark"), in: app)
        if !mode("dark").isSelected { mode("dark").tap() }
        XCTAssertTrue(until(wait) { mode("dark").isSelected }, "dark to start with")

        pick("light")
        XCTAssertFalse(mode("dark").isSelected)
        familyStillWorks("light")

        pick("glass")
        XCTAssertFalse(mode("light").isSelected)
        familyStillWorks("glass")

        // A profile still opens, and its day works.
        open("riley", in: app)
        XCTAssertTrue(mainButton(in: app).waitForExistence(timeout: wait))
        XCTAssertEqual(mainButton(in: app).label, "Pick some chores, or let me suggest some")
    }

    // MARK: Phones

    private func phonesSection(in app: XCUIApplication) {
        unlockAdmin(in: app)
        adminSection("device", in: app)
        // Right after a join the family is still arriving and the admin area can redraw under the
        // first tap; tap Device again if the section hasn't shown.
        if !app.staticTexts["Phones"].waitForExistence(timeout: 5) { adminSection("device", in: app) }
        XCTAssertTrue(app.staticTexts["Phones"].waitForExistence(timeout: wait))
    }

    private func label(startingWith text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    /// The first "Add a phone" moves the family to the relay (here, the in-memory one) and shows a code.
    func testAddAPhoneShowsACodeAndListsThisPhone() {
        let app = launch(["-resetData", "-demoFamily"])
        phonesSection(in: app)
        XCTAssertTrue(app.buttons["Join with a code"].exists, "a phone that isn't linked can join a family")
        app.buttons["Add a phone"].tap()
        XCTAssertTrue(app.otherElements["joinQR"].waitForExistence(timeout: wait), "a QR code to scan")
        XCTAssertTrue(label(startingWith: "Expires in", in: app).exists)
        screenshot("40-add-a-phone", of: app)
        app.buttons["Done"].tap()
        XCTAssertTrue(label(startingWith: "This phone · joined", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(app.staticTexts["Encrypted sync. Only this family's phones can read what's sent."].exists)
        XCTAssertFalse(app.buttons["Join with a code"].exists, "a phone in the relay doesn't join another family")
    }

    /// Scanning another phone's code swaps this phone's family for that one, through the relay.
    func testJoiningWithACodeLoadsTheOtherPhonesFamily() {
        let app = launch(["-resetData", "-demoFamily", "-scanResult", "seeded"])
        phonesSection(in: app)
        app.buttons["Join with a code"].tap()
        app.buttons["Scan the code"].tap()
        // The other phone's family (jules and kai) replaces the demo one (riley and sam). The
        // admin area closes on its own, back on settings.
        // page-feed, as on a wide screen the family is a pane of its own with no page button.
        XCTAssertTrue(until(wait) { self.isOnScreen(app.buttons["page-feed"]) }, "the admin area should close once the family has joined")
        go(to: "family", in: app)
        XCTAssertTrue(playerTile("jules", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(playerTile("kai", in: app).waitForExistence(timeout: wait))
        XCTAssertFalse(playerTile("riley", in: app).exists)
        screenshot("41-joined-family", of: app)
        // Its admin code came with it, and both phones are listed.
        phonesSection(in: app)
        XCTAssertTrue(label(startingWith: "This phone · joined", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(label(startingWith: "Phone · joined", in: app).exists)
    }

    func testACodeFromSomewhereElseIsRefused() {
        let app = launch(["-resetData", "-demoFamily", "-scanResult", "https://example.com"])
        phonesSection(in: app)
        app.buttons["Join with a code"].tap()
        app.buttons["Scan the code"].tap()
        XCTAssertTrue(app.staticTexts["That isn't a DOYOURWORK code."].waitForExistence(timeout: wait))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Join with a code"].waitForExistence(timeout: wait), "nothing changed")
    }

    /// Deleting the family from the server stops sync for good on this phone and keeps the family.
    func testDeletingTheFamilyFromTheServerKeepsItHere() {
        let app = launch(["-resetData", "-demoFamily"])
        phonesSection(in: app)
        app.buttons["Add a phone"].tap()
        XCTAssertTrue(app.otherElements["joinQR"].waitForExistence(timeout: wait))
        app.buttons["Done"].tap()
        app.buttons["Delete this family from the server…"].tap()
        app.buttons["Delete from the server"].tap()
        XCTAssertTrue(label(startingWith: "The family is only on this phone.", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(app.buttons["Join with a code"].exists)
        screenshot("42-deleted-from-server", of: app)
        goBack(in: app)
        go(to: "family", in: app)
        XCTAssertTrue(playerTile("riley", in: app).waitForExistence(timeout: wait), "the family stays on this phone")

        // Still on its own after a restart: no sync status on the settings page, nothing sent.
        app.terminate()
        let again = launch()
        go(to: "family", in: again)
        XCTAssertTrue(playerTile("riley", in: again).waitForExistence(timeout: wait))
        go(to: "settings", in: again)
        let onItsOwn = again.staticTexts["Everything here stays on this device. No accounts, nothing sent anywhere."]
        reveal(onItsOwn, in: again)
        XCTAssertFalse(again.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Sync:'")).firstMatch.exists)
    }

    /// A new phone joins from the very first screen, before anyone sets it up.
    func testANewPhoneJoinsFromTheFirstScreen() {
        let app = launch(["-resetData", "-scanResult", "seeded"])
        let join = app.buttons["Join a family"]
        XCTAssertTrue(join.waitForExistence(timeout: wait))
        join.tap()
        XCTAssertTrue(playerTile("jules", in: app).waitForExistence(timeout: wait))
        XCTAssertTrue(playerTile("kai", in: app).waitForExistence(timeout: wait))
        XCTAssertFalse(app.buttons["Set up this device"].exists, "the family it joined is already set up")
        unlockAdmin(in: app)
    }

    /// Another phone deletes the family: this one notices on its next pass and keeps what it has.
    func testAPhoneLeftOutOfTheFamilyIsToldAndKeepsItsData() {
        let app = launch(["-resetData", "-demoFamily", "-scanResult", "seeded", "-seededDeletes"])
        phonesSection(in: app)
        app.buttons["Join with a code"].tap()
        app.buttons["Scan the code"].tap()
        // Sync runs every 10 seconds, so the message can come before there's time to look
        // around: wait for it first.
        XCTAssertTrue(app.staticTexts["This phone is no longer in the family's sync. Everything on it stays here."].waitForExistence(timeout: 30))
        tapWhenReady(app.buttons["OK"], "the left-out message's OK")
        go(to: "family", in: app)
        XCTAssertTrue(playerTile("jules", in: app).waitForExistence(timeout: wait), "what it had stays")
        XCTAssertFalse(playerTile("riley", in: app).exists, "the family it joined replaced the demo one")
        phonesSection(in: app)
        XCTAssertTrue(label(startingWith: "The family is only on this phone.", in: app).waitForExistence(timeout: wait))
    }
}
