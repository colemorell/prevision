import SwiftUI

struct RoomLoadingView: View {
    let isSlow: Bool
    let error: String?
    let onRetry: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    private var statusText: String {
        if let error {
            return "Couldn't load the room. \(error)"
        }
        return isSlow ? "Still loading the room…" : "Loading room…"
    }

    var body: some View {
        ZStack {
            background
            content
        }
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                sweep = true
            }
        }
    }

    private var background: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let floorWidth = size.width * 0.6

            ZStack {
                Brand.canvas

                if !reduceMotion {
                    LinearGradient(
                        colors: [.clear, highlightColor, .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: size.width * 1.6, height: size.height * 1.6)
                    .rotationEffect(.degrees(20))
                    .offset(x: sweep ? size.width : -size.width * 1.6)
                }

                RoundedRectangle(cornerRadius: Brand.Radius.card)
                    .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    .frame(width: floorWidth, height: floorWidth / 1.4)
                    .position(x: size.width / 2, y: size.height / 2)
            }
        }
        .clipped()
    }

    private var highlightColor: Color {
        .white.opacity(colorScheme == .dark ? 0.12 : 0.35)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: Brand.Spacing.m) {
            if let error {
                VStack(spacing: Brand.Spacing.xs) {
                    Text("Couldn't load the room")
                    Text(error)
                }
                .font(Brand.Typography.caption)
                .multilineTextAlignment(.center)
                .overlayLabel()

                Button("Retry", action: onRetry)
                    .buttonStyle(.glass)
            } else {
                ProgressView()

                Text(isSlow ? "Still loading the room…" : "Loading room…")
                    .font(Brand.Typography.caption)
                    .overlayLabel()

                if isSlow {
                    Button("Retry", action: onRetry)
                        .buttonStyle(.glass)
                }
            }
        }
        .animation(Brand.Motion.standard, value: error)
        .animation(Brand.Motion.standard, value: isSlow)
    }
}
