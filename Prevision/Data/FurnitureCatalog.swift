import Foundation
import Combine

final class FurnitureCatalog: ObservableObject {
    @Published var items: [FurnitureItem] = []

    init() {
        load()
    }

    func load() {
        guard let url = Bundle.main.url(forResource: "furniture", withExtension: "json") else {
            print("furniture.json not found in Bundle")
            items = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let wrapper = try JSONDecoder().decode(FurnitureCatalogWrapper.self, from: data)
            items = wrapper.items
        } catch {
            print("Failed to decode furniture.json: \(error)")
            items = []
        }
    }

    private struct FurnitureCatalogWrapper: Codable {
        let items: [FurnitureItem]
    }
}
