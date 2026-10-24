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

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // A third finger is ignored; only the first two count.
        for touch in touches where pair.count < 2 {
            pair.append(touch)
        }
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
