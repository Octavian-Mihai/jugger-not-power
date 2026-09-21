import Foundation
import SwiftData

enum FerrumPersistence {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            User.self,
            TrainingProgram.self,
            TrainingWeek.self,
            WorkoutDay.self,
            Exercise.self,
            SetLog.self,
            ReadinessCheckIn.self
        ])
        let storeURL = storeURL
        let configuration = ModelConfiguration(
            "Ferrum",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            destroyStore(at: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create ModelContainer after resetting store: \(error)")
            }
        }
    }

    private static var storeURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("Ferrum.store")
    }

    private static func destroyStore(at url: URL) {
        let fileManager = FileManager.default
        let candidates = [
            url,
            URL(fileURLWithPath: url.path + "-wal"),
            URL(fileURLWithPath: url.path + "-shm")
        ]
        for file in candidates {
            try? fileManager.removeItem(at: file)
        }

        if let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for name in ["default.store", "default.store-wal", "default.store-shm"] {
                try? fileManager.removeItem(at: support.appendingPathComponent(name))
            }
        }
    }
}
