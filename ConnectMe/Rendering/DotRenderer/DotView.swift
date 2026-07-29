import SwiftUI

/// Animated dot representing one paired companion character.
struct DotView: View {
    let ownership: CharacterOwnership
    let animationState: DotAnimationState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pulseScale: CGFloat = 1.0
    @State private var floatOffset: CGFloat = 0.0

    private let baseSize: CGFloat = 48

    var body: some View {
        ZStack {
            // Outer glow ring — ownership-coded, color-independent shape difference
            glowRing

            // Core dot
            Circle()
                .fill(ownership.tintColor.opacity(coreOpacity))
                .frame(width: dotSize, height: dotSize)
                .overlay(
                    // Shape differentiator: inner ring for partner dot
                    ownership == .partner
                        ? AnyView(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 2))
                        : AnyView(EmptyView())
                )
                .scaleEffect(reduceMotion ? 1 : pulseScale)
        }
        .offset(y: reduceMotion ? 0 : floatOffset)
        .accessibilityLabel(ownership.accessibilityLabel)
        .onChange(of: animationState, initial: true) { _, state in
            applyAnimation(state)
        }
    }

    // MARK: - Sub-views

    private var glowRing: some View {
        Circle()
            .fill(ownership.tintColor.opacity(glowOpacity))
            .frame(width: dotSize + 16, height: dotSize + 16)
            .blur(radius: 6)
    }

    // MARK: - State-derived properties

    private var dotSize: CGFloat {
        switch animationState {
        case .sleeping: baseSize * 0.65
        case .unavailable: baseSize * 0.8
        default: baseSize
        }
    }

    private var coreOpacity: Double {
        switch animationState {
        case .active: 1.0
        case .idle, .away: 0.7
        case .sleeping: 0.35
        case .unavailable: 0.15
        }
    }

    private var glowOpacity: Double {
        switch animationState {
        case .active: 0.4
        case .idle: 0.25
        case .away: 0.15
        case .sleeping, .unavailable: 0.05
        }
    }

    // MARK: - Animation

    private func applyAnimation(_ state: DotAnimationState) {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0)) {
            pulseScale = 1.0
            floatOffset = 0
        }

        switch state {
        case .idle, .active:
            let speed: Double = state == .active ? 1.2 : 2.0
            withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
                pulseScale = state == .active ? 1.04 : 1.08
            }
        case .away:
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                floatOffset = 4
                pulseScale = 0.95
            }
        case .sleeping, .unavailable:
            break // static
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        VStack(spacing: 12) {
            ForEach(DotAnimationState.allCases, id: \.self) { state in
                DotView(ownership: .mine, animationState: state)
            }
        }
        VStack(spacing: 12) {
            ForEach(DotAnimationState.allCases, id: \.self) { state in
                DotView(ownership: .partner, animationState: state)
            }
        }
    }
    .padding(32)
    .background(Color.black)
}
