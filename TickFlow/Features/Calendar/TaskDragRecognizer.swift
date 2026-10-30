import SwiftUI
import UIKit

/// Удержание с последующим перемещением. UIKit-распознаватель не мешает скроллу:
/// пока удержание не сработало, палец прокручивает шкалу как обычно.
struct TaskDragRecognizer: UIGestureRecognizerRepresentable {
    let coordinateSpace: String
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    /// Аргумент — жест отменён системой.
    let onEnded: (Bool) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.3
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let location = context.converter.location(in: .named(coordinateSpace))
        switch recognizer.state {
        case .began: onBegan(location)
        case .changed: onChanged(location)
        case .ended: onEnded(false)
        case .cancelled, .failed: onEnded(true)
        default: break
        }
    }
}
