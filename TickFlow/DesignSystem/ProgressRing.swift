import SwiftUI

/// Кольцо прогресса: для привычек и сводки дня.
struct ProgressRing: View {
    let progress: Double
    var tint: Color = AppColors.accent
    var lineWidth: CGFloat = 3.5

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.easeOut(duration: 0.4), value: progress)
    }
}

/// Горизонтальная полоса прогресса.
struct ProgressBar: View {
    let progress: Double
    var tint: Color = AppColors.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.track)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.4), value: progress)
    }
}
