import SwiftUI

struct LightSlider: View {
    @Binding var value: Double

    @State private var lastStep: Int

    private let width: CGFloat = 44
    private let height: CGFloat = 200

    init(value: Binding<Double>) {
        _value = value
        _lastStep = State(initialValue: Int((value.wrappedValue * 10).rounded()))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .glassEffect(.regular.interactive(), in: .capsule)

            Capsule()
                .fill(Color.primary.opacity(0.16))
                .frame(height: max(0, height * value - 3))
                .padding(3)

            Image(systemName: value < 0.5 ? "sun.min" : "sun.max")
                .foregroundStyle(.secondary)
                .padding(.bottom, Brand.Spacing.s)
        }
        .frame(width: width, height: height)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let clamped = min(max(1 - drag.location.y / height, 0), 1)
                    value = clamped
                    lastStep = Int((clamped * 10).rounded())
                }
        )
        .sensoryFeedback(.selection, trigger: lastStep)
        .accessibilityElement()
        .accessibilityLabel("Light")
        .accessibilityIdentifier("LightSlider")
        .accessibilityValue("\(Int((value * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(1, value + 0.1)
            case .decrement:
                value = max(0, value - 0.1)
            @unknown default:
                break
            }
        }
    }
}
