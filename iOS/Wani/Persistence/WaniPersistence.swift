import SwiftData

enum WaniPersistence {
    static let schema = Schema([
        WaniArea.self,
        WaniProject.self,
        WaniTodo.self,
        WaniChecklistItem.self,
    ])

    static func usesEphemeralStore(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        arguments.contains("--in-memory")
            || environment["XCTestConfigurationFilePath"] != nil
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Wani-iOS",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
