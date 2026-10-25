import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Everything a print on the page responds to, decided from the first touches in one recognizer:
/// - two fingers down: scale and turn, until either finger lifts;
/// - one finger held still for a moment: move it, until it lifts;
/// - one finger that slides right away: not ours, so the page scrolls or turns.
/// One recognizer, because separate ones wait on each other and the scroll view takes the touch meanwhile.
final class PrintGestureRecognizer: UIGestureRecognizer {
    enum Mode { case none, move, transform }

    static let holdDuration: TimeInterval = 0.25
    /// How far a lone finger may drift and still count as holding.
    static let slop: CGFloat = 10

    private(set) var mode = Mode.none
    /// Scale since both fingers touched down, and the accumulated turn in radians.
    private(set) var scale: CGFloat = 1
    private(set) var rotation: CGFloat = 0
    /// How far a held print has been dragged, in window points.
    private(set) var translation: CGSize = .zero

    private var pair: [UITouch] = []
    private var soloStart: CGPoint = .zero
    private var startDistance: CGFloat = 0
    private var lastAngle: CGFloat = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // Extra fingers while moving, or a third one while transforming, are ignored.
        guard mode == .none else { return }
        for touch in touches where pair.count < 2 {
            pair.append(touch)
        }
        guard state == .possible else { return }
        if pair.count == 1 {
            soloStart = pair[0].location(in: nil)
            perform(#selector(holdElapsed), with: nil, afterDelay: Self.holdDuration)
        } else if pair.count == 2 {
            cancelHold()
            let (distance, angle) = measure()
            guard distance > 8 else { return }
            startDistance = distance
            lastAngle = angle
            mode = .transform
            state = .began
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        switch mode {
        case .none:
            guard pair.count == 1 else { return }
            let now = pair[0].location(in: nil)
            if hypot(now.x - soloStart.x, now.y - soloStart.y) > Self.slop {
                cancelHold()
                state = .failed
            }
        case .move:
            let now = pair[0].location(in: nil)
            translation = CGSize(width: now.x - soloStart.x, height: now.y - soloStart.y)
            state = .changed
        case .transform:
            guard pair.count == 2 else { return }
            let (distance, angle) = measure()
            scale = distance / startDistance
            var step = angle - lastAngle
            if step > .pi { step -= 2 * .pi }
            if step < -.pi { step += 2 * .pi }
            rotation += step
            lastAngle = angle
            state = .changed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        lift(touches)
    }

    override func reset() {
        cancelHold()
        pair = []
        mode = .none
        scale = 1
        rotation = 0
        translation = .zero
    }

    @objc private func holdElapsed() {
        guard state == .possible, mode == .none, pair.count == 1 else { return }
        soloStart = pair[0].location(in: nil)
        mode = .move
        state = .began
    }

    private func cancelHold() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(holdElapsed), object: nil)
    }

    private func lift(_ touches: Set<UITouch>) {
        let liftedTracked = pair.contains { touches.contains($0) }
        pair.removeAll { touches.contains($0) }
        guard liftedTracked else { return }
        cancelHold()
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
struct PrintGesture: UIGestureRecognizerRepresentable {
    let handlers: PrintGestureHandlers

    func makeUIGestureRecognizer(context: Context) -> PrintGestureRecognizer {
        PrintGestureRecognizer()
    }

    func handleUIGestureRecognizerAction(_ recognizer: PrintGestureRecognizer, context: Context) {
        switch (recognizer.mode, recognizer.state) {
        case (.move, .began), (.move, .changed):
            handlers.onMove(recognizer.translation)
        case (.move, .ended):
            handlers.onMoveEnded(recognizer.translation)
        case (.move, .cancelled):
            handlers.onMoveEnded(nil)
        case (.transform, .began), (.transform, .changed):
            handlers.onTransform(recognizer.scale, Double(recognizer.rotation) * 180 / .pi)
        case (.transform, .ended), (.transform, .cancelled):
            handlers.onTransformEnded()
        default:
            break
        }
    }
}

struct PrintGestureHandlers {
    /// Offset since the hold began.
    let onMove: (CGSize) -> Void
    /// The final offset, or nil when the system cancelled the drag.
    let onMoveEnded: (CGSize?) -> Void
    /// Scale since touch-down, and turn in degrees.
    let onTransform: (CGFloat, Double) -> Void
    let onTransformEnded: () -> Void
}

/// Hold-to-move plus two-finger scale and turn. iOS 18+ uses the single recognizer above;
/// iOS 17 falls back to SwiftUI's long press, magnify and rotate gestures.
struct PrintGesturesModifier: ViewModifier {
    let enabled: Bool
    let handlers: PrintGestureHandlers

    func body(content: Content) -> some View {
        if !enabled {
            content
        } else if #available(iOS 18.0, *) {
            content.gesture(PrintGesture(handlers: handlers))
        } else {
            content
                .gesture(
                    LongPressGesture(minimumDuration: PrintGestureRecognizer.holdDuration)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                        .onChanged { value in
                            guard case .second(true, let drag) = value else { return }
                            handlers.onMove(drag?.translation ?? .zero)
                        }
                        .onEnded { value in
                            guard case .second(true, let drag) = value else { return handlers.onMoveEnded(nil) }
                            handlers.onMoveEnded(drag?.translation)
                        }
                )
                .simultaneousGesture(
                    SimultaneousGesture(MagnifyGesture(minimumScaleDelta: 0.01), RotateGesture(minimumAngleDelta: .degrees(1)))
                        .onChanged { value in
                            handlers.onTransform(value.first?.magnification ?? 1, value.second?.rotation.degrees ?? 0)
                        }
                        .onEnded { _ in handlers.onTransformEnded() }
                )
        }
    }
}
