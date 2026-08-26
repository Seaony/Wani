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
        app.typeKey(.escape, modifierFlags: [])

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
