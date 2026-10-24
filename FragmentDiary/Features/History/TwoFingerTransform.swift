import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Tracks exactly two fingers and reports how far apart and how turned they are since they touched down.
/// It ends the moment either finger lifts, so a print can never keep scaling or turning under one finger
/// (which the system pinch and rotation recognizers sometimes allow).
final class TwoFingerTransformRecognizer: UIGestureRecognizer {
    private(set) var scale: CGFloat = 1
    /// Accumulated turn in radians; past half a turn it keeps counting instead of wrapping.
    private(set) var rotation: CGFloat = 0

    private var pair: [UITouch] = []
    private var startDistance: CGFloat = 0
    private var lastAngle: CGFloat = 0
    private var soloStart: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // A third finger is ignored; only the first two count.
        for touch in touches where pair.count < 2 {
            pair.append(touch)
        }
        if pair.count == 1, soloStart == nil { soloStart = pair[0].location(in: nil) }
        guard pair.count == 2, state == .possible else { return }
        let (distance, angle) = measure()
        guard distance > 8 else { return }
        startDistance = distance
        lastAngle = angle
        scale = 1
        rotation = 0
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        // A lone finger that travels is a swipe or scroll, not the start of a pinch: let it go to the
        // page turn or the scroll view instead of holding on until it lifts.
        if state == .possible, pair.count == 1, let soloStart {
            let now = pair[0].location(in: nil)
            if hypot(now.x - soloStart.x, now.y - soloStart.y) > 10 { state = .failed }
            return
        }
        guard pair.count == 2, state == .began || state == .changed else { return }
        let (distance, angle) = measure()
        scale = distance / startDistance
        var step = angle - lastAngle
        if step > .pi { step -= 2 * .pi }
        if step < -.pi { step += 2 * .pi }
        rotation += step
        lastAngle = angle
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches)
    }

    override func reset() {
        pair = []
        soloStart = nil
        scale = 1
        rotation = 0
    }

    private func lift(_ touches: Set<UITouch>) {
        let liftedTracked = pair.contains { touches.contains($0) }
        pair.removeAll { touches.contains($0) }
        guard liftedTracked else { return }
        switch state {
        case .began, .changed:
            state = .ended
        case .possible where pair.isEmpty:
            state = .failed
        default:
            break
        }
    }

    /// Measured in window coordinates, so the print turning and scaling under the fingers doesn't feed back.
    private func measure() -> (distance: CGFloat, angle: CGFloat) {
        let a = pair[0].location(in: nil)
        let b = pair[1].location(in: nil)
        return (hypot(b.x - a.x, b.y - a.y), atan2(b.y - a.y, b.x - a.x))
    }
}

@available(iOS 18.0, *)
struct TwoFingerTransformGesture: UIGestureRecognizerRepresentable {
    /// Scale since touch-down, and turn in degrees.
    let onChanged: (CGFloat, Double) -> Void
    let onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> TwoFingerTransformRecognizer {
        TwoFingerTransformRecognizer()
    }

    func handleUIGestureRecognizerAction(_ recognizer: TwoFingerTransformRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onChanged(recognizer.scale, Double(recognizer.rotation) * 180 / .pi)
        case .ended, .cancelled:
            onEnded()
        default:
            break
        }
    }
}

/// Two-finger scale and turn. iOS 18+ uses the strict two-finger recognizer; iOS 17 falls back to the system gestures.
struct TwoFingerTransformModifier: ViewModifier {
    let enabled: Bool
    let onChanged: (CGFloat, Double) -> Void
    let onEnded: () -> Void

    func body(content: Content) -> some View {
        if !enabled {
            content
        } else if #available(iOS 18.0, *) {
            content.gesture(TwoFingerTransformGesture(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(
                SimultaneousGesture(MagnifyGesture(minimumScaleDelta: 0.01), RotateGesture(minimumAngleDelta: .degrees(1)))
                    .onChanged { value in
                        onChanged(value.first?.magnification ?? 1, value.second?.rotation.degrees ?? 0)
                    }
                    .onEnded { _ in onEnded() }
            )
        }
    }
}

/// Hold, then drag. Built on UIKit's long press so a quick swipe that starts on a print still scrolls
/// or turns the page; SwiftUI's long press inside a scroll view swallows those swipes.
final class HoldToMoveRecognizer: UILongPressGestureRecognizer {
    fileprivate var start: CGPoint = .zero

    fileprivate var translation: CGSize {
        let now = location(in: nil)
        return CGSize(width: now.x - start.x, height: now.y - start.y)
    }
}

@available(iOS 18.0, *)
struct HoldToMoveGesture: UIGestureRecognizerRepresentable {
    let onChanged: (CGSize) -> Void
    /// The final offset, or nil when the system cancelled the drag.
    let onEnded: (CGSize?) -> Void

    func makeUIGestureRecognizer(context: Context) -> HoldToMoveRecognizer {
        let recognizer = HoldToMoveRecognizer()
        recognizer.minimumPressDuration = 0.25
        recognizer.allowableMovement = 10
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: HoldToMoveRecognizer, context: Context) {
        switch recognizer.state {
        case .began:
            recognizer.start = recognizer.location(in: nil)
            onChanged(.zero)
        case .changed:
            onChanged(recognizer.translation)
        case .ended:
            onEnded(recognizer.translation)
        case .cancelled:
            onEnded(nil)
        default:
            break
        }
    }
}

/// Hold-to-move for a print. iOS 17 falls back to SwiftUI's long press and drag.
struct HoldToMoveModifier: ViewModifier {
    let enabled: Bool
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize?) -> Void

    func body(content: Content) -> some View {
        if !enabled {
            content
        } else if #available(iOS 18.0, *) {
            content.gesture(HoldToMoveGesture(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.gesture(
                LongPressGesture(minimumDuration: 0.25)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                    .onChanged { value in
                        guard case .second(true, let drag) = value else { return }
                        onChanged(drag?.translation ?? .zero)
                    }
                    .onEnded { value in
                        guard case .second(true, let drag) = value else { return onEnded(nil) }
                        onEnded(drag?.translation)
                    }
            )
        }
    }
}
