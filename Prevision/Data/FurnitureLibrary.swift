import Foundation
import Combine
import UIKit
import UniformTypeIdentifiers
import QuickLookThumbnailing

private struct FurnitureOverride: Codable {
    let name: String?
    let widthInches: Double?
    let depthInches: Double?
    let heightInches: Double?
    let zUp: Bool?
}

private struct FurnitureOverridesFile: Codable {
    let overrides: [String: FurnitureOverride]
}

private nonisolated final class ThumbnailResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resume(with image: UIImage?, continuation: CheckedContinuation<UIImage?, Never>) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: image)
    }
}

final class FurnitureLibrary: ObservableObject {
    static let environmentModels: Set<String> = ["Modern_Apartment"]

    @Published private(set) var items: [FurnitureItem] = []
    @Published private(set) var thumbnails: [String: UIImage] = [:]

    init() {
        reload()
    }

    func reload() {
        let overrides = Self.loadOverrides()
        let bundled = Self.bundledURLs()
            .map { Self.buildItem(url: $0, isImported: false, overrides: overrides) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let imported = Self.importedURLs()
            .map { Self.buildItem(url: $0, isImported: true, overrides: overrides) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        items = bundled + imported
    }

    func item(withID id: String) -> FurnitureItem? {
        items.first { $0.id == id }
    }

    func importModels(from urls: [URL]) throws {
        let dir = Self.importsDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for url in urls {
            guard Self.isUSDZ(url) else { continue }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let destination = dir.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
        }
        reload()
    }

    func loadThumbnails() async {
        let pending = items.filter { thumbnails[$0.id] == nil }
        guard !pending.isEmpty else { return }
        let cacheDir = Self.thumbnailCacheDirectory()
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for item in pending {
                let timestamp = Self.modificationTimestamp(for: item.url)
                let cacheURL = cacheDir.appendingPathComponent("\(item.id)-\(timestamp).png")
                group.addTask { [weak self] in
                    guard let self else { return (item.id, nil) }
                    let image = await self.generateThumbnail(for: item, cacheURL: cacheURL)
                    return (item.id, image)
                }
            }
            for await (id, image) in group {
                if let image {
                    thumbnails[id] = image
                }
            }
        }
    }

    static func displayName(for fileName: String) -> String {
        let withoutExtension = (fileName as NSString).deletingPathExtension
        let normalized = withoutExtension
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let words = normalized.split(separator: " ", omittingEmptySubsequences: true)
        return words.map { word -> String in
            let lower = word.lowercased()
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined(separator: " ")
    }

    private nonisolated func generateThumbnail(for item: FurnitureItem, cacheURL: URL) async -> UIImage? {
        if let data = try? Data(contentsOf: cacheURL), let image = UIImage(data: data) {
            return image
        }
        guard let image = await Self.requestThumbnail(for: item) else { return nil }
        try? image.pngData()?.write(to: cacheURL)
        return image
    }

    private nonisolated static func requestThumbnail(for item: FurnitureItem) async -> UIImage? {
        if let image = await Self.quickLookThumbnail(forFileAt: item.url) {
            return image
        }
        return await ThumbnailRenderer.render(modelAt: item.url, zUp: item.zUp)
    }

    private nonisolated static func quickLookThumbnail(forFileAt url: URL) async -> UIImage? {
        await withTaskGroup(of: UIImage?.self) { group in
            group.addTask {
                await Self.quickLookRepresentation(forFileAt: url)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(2))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private nonisolated static func quickLookRepresentation(forFileAt url: URL) async -> UIImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 240, height: 240),
            scale: 3.0,
            representationTypes: .thumbnail
        )
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            let resumeGuard = ThumbnailResumeGuard()
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                resumeGuard.resume(with: representation?.uiImage, continuation: continuation)
            }
        }
    }

    private static func isUSDZ(_ url: URL) -> Bool {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.conforms(to: .usdz)
        }
        return url.pathExtension.lowercased() == "usdz"
    }

    private static func loadOverrides() -> [String: FurnitureOverride] {
        guard let url = Bundle.main.url(forResource: "furniture", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(FurnitureOverridesFile.self, from: data) else {
            return [:]
        }
        return decoded.overrides
    }

    private static func bundledURLs() -> [URL] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "usdz", subdirectory: nil) ?? []
        return urls.filter { !environmentModels.contains($0.deletingPathExtension().lastPathComponent) }
    }

    private static func importsDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Prevision/Furniture", isDirectory: true)
    }

    private static func importedURLs() -> [URL] {
        let dir = importsDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return contents.filter { isUSDZ($0) }
    }

    private static func buildItem(url: URL, isImported: Bool, overrides: [String: FurnitureOverride]) -> FurnitureItem {
        let id = url.deletingPathExtension().lastPathComponent
        let override = overrides[id]
        let name = override?.name ?? displayName(for: url.lastPathComponent)
        var targetSize: SIMD3<Float>?
        if let width = override?.widthInches, let depth = override?.depthInches, let height = override?.heightInches {
            let inchesToMeters: Float = 0.0254
            targetSize = SIMD3<Float>(Float(width) * inchesToMeters, Float(height) * inchesToMeters, Float(depth) * inchesToMeters)
        }
        return FurnitureItem(
            id: id,
            name: name,
            url: url,
            targetSizeMeters: targetSize,
            zUp: override?.zUp ?? false,
            isImported: isImported
        )
    }

    private static func thumbnailCacheDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("Prevision/Thumbnails", isDirectory: true)
    }

    private static func modificationTimestamp(for url: URL) -> Int {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let date = values?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
        return Int(date.timeIntervalSince1970)
    }
}
