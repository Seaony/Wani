import SwiftData

enum WaniPersistence {
    static let cloudKitContainerIdentifier = "iCloud.com.seaony.wani.Wani"

    static let schema = Schema([
        WaniArea.self,
        WaniProject.self,
        WaniHeading.self,
        WaniTodo.self,
        WaniChecklistItem.self,
    ])

    static func usesEphemeralStore(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        arguments.contains("--ui-testing")
            || environment["XCTestConfigurationFilePath"] != nil
    }

    static func makeContainer(
        inMemory: Bool = false,
        cloudSync: Bool = true
    ) throws -> ModelContainer {
        let database: ModelConfiguration.CloudKitDatabase = cloudSync
            ? .private(cloudKitContainerIdentifier)
            : .none
        let configuration = ModelConfiguration(
            "Wani",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: database
        )

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
