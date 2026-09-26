import SwiftUI

struct FurnitureListView: View {
    @EnvironmentObject var catalog: FurnitureCatalog
    @EnvironmentObject var scene: SceneController

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Brand.Spacing.s) {
                ForEach(catalog.items) { item in
                    let isArmed = scene.armedItem?.id == item.id
                    Button {
                        withAnimation(Brand.Motion.standard) { scene.arm(item) }
                    } label: {
                        Text(item.name)
                            .font(Brand.Typography.label)
                            .padding(.horizontal, Brand.Spacing.m)
                            .padding(.vertical, Brand.Spacing.s)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(isArmed ? Brand.cta : .secondary)
                    .accessibilityAddTraits(isArmed ? .isSelected : [])
                }
            }
            .padding(.horizontal, Brand.Spacing.m)
            .padding(.vertical, Brand.Spacing.s)
        }
        .background(.bar)
    }
}
