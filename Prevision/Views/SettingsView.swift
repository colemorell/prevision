import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var library: FurnitureLibrary
    @EnvironmentObject var store: DesignStore
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Library") {
                    LabeledContent("Furniture Models", value: "\(library.items.count)")
                    LabeledContent("Designs", value: "\(store.designs.count)")
                }
                Section {
                    Text("Add a model by dropping a .usdz file into Prevision/Resources in Xcode, or import one from Files using the import button in the furniture panel. The file name becomes the item name.")
                        .font(Brand.Typography.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Adding Furniture")
                }
                Section("About") {
                    LabeledContent("Version", value: version)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
