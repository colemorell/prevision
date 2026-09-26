import SwiftUI

struct FurnitureListView: View {
    @EnvironmentObject var catalog: FurnitureCatalog
    @EnvironmentObject var scene: SceneController

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(catalog.items) { item in
                    VStack {
                        Text(item.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 80, height: 80)
                    .background(scene.armedItem?.id == item.id ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .onTapGesture {
                        scene.arm(item)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 100)
    }
}

#Preview {
    FurnitureListView()
        .environmentObject(FurnitureCatalog())
        .environmentObject(SceneController())
}
