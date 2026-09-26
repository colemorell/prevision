import SwiftUI
import UniformTypeIdentifiers

struct AssetPoolView: View {
    @EnvironmentObject var library: FurnitureLibrary
    @EnvironmentObject var scene: SceneController
    var axis: Axis = .vertical
    var dragSpace: NamedCoordinateSpace = .named("designer")
    var onDragChanged: (FurnitureItem, CGPoint) -> Void = { _, _ in }
    var onDragEnded: (FurnitureItem, CGPoint?) -> Void = { _, _ in }
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Furniture")
                    .font(Brand.Typography.label)
                Spacer()
                Button("Import Models", systemImage: "square.and.arrow.down") { showImporter = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(.primary)
            }
            .padding(.horizontal, Brand.Spacing.m)
            .padding(.vertical, Brand.Spacing.s)

            ScrollView(axis == .vertical ? .vertical : .horizontal, showsIndicators: false) {
                let layout = axis == .vertical
                    ? AnyLayout(VStackLayout(spacing: Brand.Spacing.s))
                    : AnyLayout(HStackLayout(spacing: Brand.Spacing.s))
                layout {
                    ForEach(library.items) { item in
                        AssetTile(item: item, thumbnail: library.thumbnails[item.id], isArmed: scene.armedItem?.id == item.id)
                            .frame(width: axis == .vertical ? nil : 96)
                            .onTapGesture { scene.arm(item) }
                            .gesture(dragGesture(for: item))
                    }
                }
                .padding(.horizontal, Brand.Spacing.s)
                .padding(.bottom, Brand.Spacing.m)
            }
        }
        .background(.bar)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.usdz], allowsMultipleSelection: true) { result in
            do {
                try library.importModels(from: result.get())
                Task { await library.loadThumbnails() }
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("Couldn't Import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .task { await library.loadThumbnails() }
    }

    private func dragGesture(for item: FurnitureItem) -> some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: dragSpace))
            .onChanged { value in
                if case .second(true, let drag?) = value {
                    onDragChanged(item, drag.location)
                }
            }
            .onEnded { value in
                if case .second(true, let drag?) = value {
                    onDragEnded(item, drag.location)
                } else {
                    onDragEnded(item, nil)
                }
            }
    }
}

private struct AssetTile: View {
    let item: FurnitureItem
    let thumbnail: UIImage?
    let isArmed: Bool

    var body: some View {
        VStack(spacing: Brand.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: Brand.Radius.control)
                    .fill(Brand.canvas)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .padding(Brand.Spacing.s)
                        .transition(.opacity)
                } else {
                    ProgressView()
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                RoundedRectangle(cornerRadius: Brand.Radius.control)
                    .strokeBorder(Brand.cta, lineWidth: isArmed ? 2 : 0)
            }
            Text(item.name)
                .font(Brand.Typography.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(Brand.Spacing.xs)
        .contentShape(.rect)
        .animation(Brand.Motion.standard, value: isArmed)
        .animation(Brand.Motion.standard, value: thumbnail != nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isArmed ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Drag into the room, or tap then tap the floor")
    }
}
