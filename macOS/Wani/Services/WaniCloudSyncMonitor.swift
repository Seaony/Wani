import CloudKit
import Combine
import CoreData
import Foundation

enum WaniCloudAccountState: Equatable {
    case localOnly
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine

    init(_ status: CKAccountStatus) {
        switch status {
        case .available:
            self = .available
        case .noAccount:
            self = .noAccount
        case .restricted:
            self = .restricted
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        case .couldNotDetermine:
            self = .couldNotDetermine
        @unknown default:
            self = .couldNotDetermine
        }
    }

    var title: String {
        switch self {
        case .localOnly: "Local development mode"
        case .checking: "Checking iCloud"
        case .available: "iCloud available"
        case .noAccount: "Sign in to iCloud"
        case .restricted: "iCloud restricted"
        case .temporarilyUnavailable: "iCloud temporarily unavailable"
        case .couldNotDetermine: "Unable to check iCloud"
        }
    }

    var detail: String {
        switch self {
        case .localOnly:
            "This Debug launch is using the local store. Pass --cloud-sync to exercise CloudKit."
        case .checking:
            "Reading the current iCloud account status."
        case .available:
            "Changes sync automatically through the private CloudKit database."
        case .noAccount:
            "Sign in to an iCloud account in System Settings to enable sync."
        case .restricted:
            "This Mac does not currently allow access to the iCloud account."
        case .temporarilyUnavailable:
            "CloudKit will retry automatically when the service becomes available."
        case .couldNotDetermine:
            "The current iCloud account status could not be determined."
        }
    }
}

@MainActor
final class WaniCloudSyncMonitor: ObservableObject {
    @Published private(set) var accountState: WaniCloudAccountState
    @Published private(set) var lastActivity: String?
    @Published private(set) var lastActivityDate: Date?
    @Published private(set) var lastError = ""

    private let enabled: Bool
    private let container: CKContainer?
    private var eventObserver: NSObjectProtocol?

    init(
        enabled: Bool,
        containerIdentifier: String = WaniPersistence.cloudKitContainerIdentifier
    ) {
        self.enabled = enabled
        container = enabled ? CKContainer(identifier: containerIdentifier) : nil
        accountState = enabled ? .checking : .localOnly

        guard enabled else { return }

        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }

            MainActor.assumeIsolated {
                self?.record(event)
            }
        }
        refreshAccountStatus()
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
    }

    func refreshAccountStatus() {
        guard enabled, let container else {
            accountState = .localOnly
            return
        }

        accountState = .checking
        Task {
            do {
                accountState = WaniCloudAccountState(try await container.accountStatus())
                if accountState == .available {
                    lastError = ""
                }
            } catch {
                accountState = .couldNotDetermine
                lastError = error.localizedDescription
            }
        }
    }

    private func record(_ event: NSPersistentCloudKitContainer.Event) {
        guard let endDate = event.endDate else { return }

        let operation: String
        switch event.type {
        case .setup:
            operation = "CloudKit setup"
        case .import:
            operation = "CloudKit import"
        case .export:
            operation = "CloudKit export"
        @unknown default:
            operation = "CloudKit activity"
        }

        lastActivity = "\(operation) \(event.succeeded ? "completed" : "failed")"
        lastActivityDate = endDate
        lastError = event.error?.localizedDescription ?? ""
    }
}
