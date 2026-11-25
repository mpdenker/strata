import SwiftUI

// Scroll-driven animation, two layers (SPEC.md §5.2):
//   A. Entrance: every section eases in as it scrolls up from the bottom edge (scrollTransition).
//   B. Build: each visual draws itself step by step, once, the first time it's mostly on screen.
// Reduce Motion turns both off: sections are static and visuals start fully built.

/// Remembers which sections have been seen and which builds have finished, for one lesson session.
/// Built visuals stay built, so scrolling back up never replays them.
@Observable
final class RevealState {
    var visible: Set<String> = []
    var built: Set<String> = []
}

enum LessonScroll {
    static let space = "lessonScroll"
}

/// Height of the lesson's scroll viewport, for the visibility check.
private struct ViewportHeightKey: EnvironmentKey { static let defaultValue: CGFloat = 800 }
extension EnvironmentValues {
    var viewportHeight: CGFloat {
        get { self[ViewportHeightKey.self] }
        set { self[ViewportHeightKey.self] = newValue }
    }
}

// MARK: - Layer A: entrance

/// Turns scroll effects off (used for screenshots and UI tests). Reduce Motion does the same for users.
private struct ScrollEffectsEnabledKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var scrollEffectsEnabled: Bool {
        get { self[ScrollEffectsEnabledKey.self] }
        set { self[ScrollEffectsEnabledKey.self] = newValue }
    }
}

private struct EntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scrollEffectsEnabled) private var enabled

    func body(content: Content) -> some View {
        if reduceMotion || !enabled {
            content
        } else {
            // Identity once ≥ 25% visible, so tall sections never stay dimmed while you read them.
            // Only the bottom edge animates (entering); sections leaving at the top aren't faded.
            content.scrollTransition(.interactive.threshold(.visible(0.25))) { view, phase in
                let entering = phase == .bottomTrailing
                return view
                    .opacity(entering ? 0.25 : 1)
                    .offset(y: entering ? 28 : 0)
                    .scaleEffect(entering ? 0.97 : 1)
            }
        }
    }
}

// MARK: - First-visible detection

/// Fires once when enough of the view is on screen: 35% of the view, or 35% of the viewport for
/// views taller than the screen (so very tall sections still trigger).
private struct FirstVisibleModifier: ViewModifier {
    let id: String
    @Environment(RevealState.self) private var state
    @Environment(\.viewportHeight) private var viewport

    func body(content: Content) -> some View {
        if state.visible.contains(id) {
            content
        } else {
            content.onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named(LessonScroll.space)) }) { frame in
                let shown = min(frame.maxY, viewport) - max(frame.minY, 0)
                let needed = 0.35 * min(frame.height, viewport)
                if frame.height > 0, shown >= needed {
                    state.visible.insert(id)
                }
            }
        }
    }
}

extension View {
    func sectionEntrance() -> some View { modifier(EntranceModifier()) }
    func trackFirstVisible(id: String) -> some View { modifier(FirstVisibleModifier(id: id)) }
}

// MARK: - Layer B: staged build

/// Drives a step count from 0 up to `total` once its section becomes visible.
/// `content(n)` draws the visual with parts 1…n shown.
struct Staged<Content: View>: View {
    let id: String
    let total: Int
    var stagger: Duration = .milliseconds(260)
    @ViewBuilder let content: (Int) -> Content

    @Environment(RevealState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sectionID) private var sectionID
    @State private var shown = 0

    private var isVisible: Bool { state.visible.contains(sectionID) }

    var body: some View {
        let complete = reduceMotion || state.built.contains(id)
        content(complete ? total : shown)
            .task(id: isVisible) {
                guard isVisible, !complete, shown == 0 else { return }
                for step in 1...max(1, total) {
                    withAnimation(.smooth(duration: 0.55)) { shown = step }
                    try? await Task.sleep(for: stagger)
                    if Task.isCancelled { return }
                }
                state.built.insert(id)
            }
    }
}

/// The id of the section a view sits in, so nested visuals know when their section is visible.
private struct SectionIDKey: EnvironmentKey { static let defaultValue = "" }
extension EnvironmentValues {
    var sectionID: String {
        get { self[SectionIDKey.self] }
        set { self[SectionIDKey.self] = newValue }
    }
}

/// Fade + rise for a part that appears at a given build step.
struct StepAppear: ViewModifier {
    let visible: Bool
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)
    }
}

extension View {
    func appears(_ visible: Bool) -> some View { modifier(StepAppear(visible: visible)) }
}
