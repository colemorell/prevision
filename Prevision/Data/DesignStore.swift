import Foundation
import Combine

final class DesignStore: ObservableObject {
    @Published private(set) var designs: [Design]

    private let fileURL: URL

    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = appSupport.appendingPathComponent("Prevision", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("designs.json")
        self.fileURL = fileURL

        if let data = try? Data(contentsOf: fileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let loaded = try? decoder.decode([Design].self, from: data) {
                self.designs = loaded.sorted { $0.updatedAt > $1.updatedAt }
            } else {
                self.designs = []
            }
        } else {
            self.designs = []
        }
    }

    @discardableResult
    func create(named name: String) -> Design {
        let design = Design(name: name)
        designs.insert(design, at: 0)
        resort()
        persist()
        return design
    }

    func save(_ design: Design) {
        var updated = design
        updated.updatedAt = .now
        if let index = designs.firstIndex(where: { $0.id == updated.id }) {
            designs[index] = updated
        } else {
            designs.append(updated)
        }
        resort()
        persist()
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = designs.firstIndex(where: { $0.id == id }) else { return }
        designs[index].name = name
        designs[index].updatedAt = .now
        resort()
        persist()
    }

    func delete(_ id: UUID) {
        designs.removeAll { $0.id == id }
        persist()
    }

    func design(withID id: UUID) -> Design? {
        designs.first { $0.id == id }
    }

    func nextDefaultName() -> String {
        let existingNames = Set(designs.map(\.name))
        var index = 1
        while existingNames.contains("Design \(index)") {
            index += 1
        }
        return "Design \(index)"
    }

    private func resort() {
        designs.sort { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        let snapshot = designs
        let destination = fileURL
        Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: destination, options: .atomic)
        }
    }
}
