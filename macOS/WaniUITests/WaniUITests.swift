import XCTest

final class WaniUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-appearance", "light",
            "-launchDestination", "today",
            "-showMenuBarIcon", "NO",
            "-deadlineNotificationsEnabled", "NO",
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testTodoLifecycleAndSearch() throws {
        createTodo(named: "UI Test Task")

        todoButton(named: "UI Test Task").click()
        let titleField = app.textFields["To-do"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.click()
        titleField.typeKey("a", modifierFlags: .command)
        app.typeText("Edited UI Test Task")

        app.buttons["Search"].firstMatch.click()
        let searchField = app.textFields["Search everything"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        app.typeText("Edited UI")
        XCTAssertTrue(app.staticTexts["1 found"].waitForExistence(timeout: 2))
        app.typeKey(.return, modifierFlags: [])
        XCTAssertFalse(searchField.waitForExistence(timeout: 1))

        app.buttons["Complete"].firstMatch.click()
        app.buttons["Logbook"].click()
        let completedTodo = todoButton(named: "Edited UI Test Task")
        XCTAssertTrue(completedTodo.waitForExistence(timeout: 2))
        completedTodo.click()
        app.buttons["Reopen"].firstMatch.click()

        app.buttons["Today"].click()
        let reopenedTodo = todoButton(named: "Edited UI Test Task")
        XCTAssertTrue(reopenedTodo.waitForExistence(timeout: 2))
        reopenedTodo.click()
        app.buttons["Move to Trash"].click()

        app.buttons["Trash"].click()
        let trashedTodo = todoButton(named: "Edited UI Test Task")
        XCTAssertTrue(trashedTodo.waitForExistence(timeout: 2))
        trashedTodo.click()
        app.buttons["Restore"].click()
        XCTAssertFalse(trashedTodo.waitForExistence(timeout: 1))
    }

    func testSettingsNavigation() throws {
        app.buttons["Settings"].click()
        XCTAssertTrue(app.buttons["Close Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Light"].exists)
        XCTAssertTrue(app.buttons["Dark"].exists)

        app.buttons["settings-tab-General"].click()
        XCTAssertTrue(app.staticTexts["Startup"].waitForExistence(timeout: 2))

        app.buttons["settings-tab-Quick Entry"].click()
        XCTAssertTrue(app.staticTexts["Dismiss"].waitForExistence(timeout: 2))

        app.buttons["Close Settings"].click()
        XCTAssertFalse(app.buttons["Close Settings"].waitForExistence(timeout: 1))
    }

    func testMoveTodoToInbox() throws {
        createTodo(named: "Move UI Test Task")

        todoButton(named: "Move UI Test Task").click()
        app.typeKey("m", modifierFlags: [.command, .shift])

        let inboxDestination = app.buttons["Inbox, No Project"]
        XCTAssertTrue(inboxDestination.waitForExistence(timeout: 2))
        inboxDestination.click()

        app.buttons["Inbox"].click()
        XCTAssertTrue(todoButton(named: "Move UI Test Task").waitForExistence(timeout: 2))
    }

    func testBatchScheduleToSomeday() throws {
        createTodo(named: "First Batch Task")
        createTodo(named: "Second Batch Task")

        app.typeKey("a", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["2 selected"].waitForExistence(timeout: 2))

        app.typeKey("s", modifierFlags: .command)
        let scheduleSomeday = app.buttons["Schedule Someday"]
        XCTAssertTrue(scheduleSomeday.waitForExistence(timeout: 2))
        scheduleSomeday.click()

        app.buttons["Someday"].click()
        XCTAssertTrue(todoButton(named: "First Batch Task").waitForExistence(timeout: 2))
        XCTAssertTrue(todoButton(named: "Second Batch Task").waitForExistence(timeout: 2))
    }

    func testDirectScheduleShortcut() throws {
        createTodo(named: "Shortcut Schedule Task")

        app.typeKey("a", modifierFlags: .command)
        app.typeKey("o", modifierFlags: .command)

        app.buttons["Someday"].click()
        XCTAssertTrue(todoButton(named: "Shortcut Schedule Task").waitForExistence(timeout: 2))
    }

    func testBatchTagsAreSearchable() throws {
        createTodo(named: "First Tagged Task")
        createTodo(named: "Second Tagged Task")

        app.typeKey("a", modifierFlags: .command)
        app.buttons["Tags"].click()

        let tagField = app.textFields["Filter or add tag"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 2))
        tagField.click()
        app.typeText("Batch QA")
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.escape, modifierFlags: [])

        app.typeKey("f", modifierFlags: .command)
        let searchField = app.textFields["Search everything"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.click()
        app.typeText("Batch QA")
        XCTAssertTrue(app.staticTexts["2 found"].waitForExistence(timeout: 2))
    }

    func testDuplicateSelectedTodo() throws {
        createTodo(named: "Duplicate UI Test Task")

        app.typeKey("a", modifierFlags: .command)
        app.typeKey("d", modifierFlags: .command)

        let matchingTodos = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Duplicate UI Test Task")
        )
        XCTAssertEqual(matchingTodos.count, 2)
        XCTAssertTrue(app.staticTexts["1 selected"].exists)
    }

    func testBatchDateMetadataEditorsAreAvailable() throws {
        createTodo(named: "First Dated Task")
        createTodo(named: "Second Dated Task")

        app.typeKey("a", modifierFlags: .command)
        app.typeKey("s", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Add Reminder"].waitForExistence(timeout: 2))
        app.typeKey(.escape, modifierFlags: [])

        app.menuBars.menuBarItems["Items"].click()
        XCTAssertTrue(app.menuItems["Move…"].exists)
        XCTAssertTrue(app.menuItems["Tags…"].exists)
        XCTAssertTrue(app.menuItems["Mark as Completed"].exists)
        XCTAssertTrue(app.menuItems["Mark as Canceled"].exists)
        app.menuItems["Deadline…"].click()
        XCTAssertTrue(app.buttons["Apply Deadline"].waitForExistence(timeout: 2))
    }

    func testRepeatEditorIsAvailableFromItemsMenu() throws {
        createTodo(named: "Repeat UI Test Task")
        todoButton(named: "Repeat UI Test Task").click()

        app.menuBars.menuBarItems["Items"].click()
        app.menuItems["Repeat…"].click()

        XCTAssertTrue(app.buttons["Save Repeat"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.radioButtons["Regularly"].exists)
        XCTAssertTrue(app.radioButtons["After Completion"].exists)
        app.radioButtons["Regularly"].click()
        XCTAssertTrue(app.popUpButtons["Repeat End"].exists)
        app.popUpButtons["Frequency"].click()
        app.menuItems["Month"].click()
        XCTAssertTrue(app.buttons["Add Repeat Date"].exists)
        XCTAssertTrue(app.staticTexts["Next"].exists)
        XCTAssertTrue(app.checkBoxes["Add Reminder"].exists)
        XCTAssertTrue(app.checkBoxes["Add Deadline"].exists)
    }

    private func createTodo(named title: String) {
        app.buttons["New To-Do"].click()
        let titleField = app.textFields["What's on your mind?"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.click()
        app.typeText(title)
        app.buttons["Save"].click()
        XCTAssertTrue(todoButton(named: title).waitForExistence(timeout: 2))
    }

    private func todoButton(named title: String) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", title)
        ).firstMatch
    }
}
