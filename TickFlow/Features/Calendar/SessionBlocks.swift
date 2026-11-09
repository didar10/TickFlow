import SwiftUI

/// Место полосы учтённого времени: у правого края колонки дня.
enum SessionBlockFrame {
    static func rect(geometry: TimelineGeometry, columnWidth: CGFloat, dayIndex: Int, start: Int, end: Int) -> CGRect {
        let lane = geometry.sessionLaneWidth
        let wide = geometry.showsSessionLabels
        let height = max(wide ? 16 : 6, geometry.height(minutes: end - start) - 2)
        return CGRect(
            x: geometry.gutterWidth + CGFloat(dayIndex + 1) * columnWidth - lane + (wide ? 2 : 1),
            y: geometry.y(forMinute: start) + 1,
            width: max(0, lane - (wide ? 6 : 2)),
            height: height
        )
    }
}

/// Полоса записи: в «Дне» — штриховка с подписью, в узких колонках — сплошная.
struct SessionBlockView: View {
    let title: String
    let detail: String
    let colorHex: String
    let isInterrupted: Bool
    let isWide: Bool
    let height: CGFloat

    var body: some View {
        let style = CategoryStyle(hex: colorHex)
        if isWide {
            VStack(alignment: .leading, spacing: 0) {
                if height >= 15 {
                    Text(title).font(.system(size: 10.5, weight: .bold)).lineLimit(1)
                }
                if height >= 30 {
                    Text(detail).font(.system(size: 10)).opacity(0.8).lineLimit(1)
                }
            }
            .foregroundStyle(style.foreground)
            .padding(.leading, 6)
            .padding(.trailing, 4)
            .padding(.vertical, height >= 30 ? 3 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                ZStack {
                    style.background
                    DiagonalStripes(spacing: 8, lineWidth: 4).fill(style.tint.opacity(0.19))
                }
            }
            .overlay(alignment: .leading) { Rectangle().fill(style.tint).frame(width: 3) }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else if isInterrupted {
            HorizontalStripes(period: 5, lineHeight: 3)
                .fill(style.tint)
                .background(style.tint.opacity(0.44))
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(style.tint)
        }
    }
}

/// Идущая сессия: растёт вместе со временем и мерцает. Читает движок сама,
/// чтобы каждый тик перерисовывал только её, а не всю сетку.
struct LiveSessionBlock: View {
    @Environment(FocusEngine.self) private var focus
    let geometry: TimelineGeometry
    let columnWidth: CGFloat
    let dayIndex: Int
    let minuteOf: (Date) -> Int
    let onTap: () -> Void
    @State private var dimmed = false

    var body: some View {
        if let live = focus.liveInterval {
            let start = minuteOf(live.start)
            let minutes = max(1, Int(live.end.timeIntervalSince(live.start) / 60))
            let end = min(1439, start + minutes)
            let rect = SessionBlockFrame.rect(geometry: geometry, columnWidth: columnWidth, dayIndex: dayIndex, start: start, end: end)
            let task = focus.task
            let title = task?.title ?? L10n.Focus.focusSession
            let detail = FocusText.kind(live.kind) + " · " + DateFormatting.duration(minutes: minutes) + " · " + L10n.Calendar.sessionNow
            SessionBlockView(
                title: title, detail: detail, colorHex: task?.list?.colorHex ?? AppColors.fallbackList,
                isInterrupted: false, isWide: geometry.showsSessionLabels, height: rect.height
            )
            .frame(width: rect.width, height: rect.height)
            .opacity(dimmed ? 0.55 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { dimmed = true }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .offset(x: rect.minX, y: rect.minY)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title + ", " + detail)
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// Штриховка под 135°.
struct DiagonalStripes: Shape {
    var spacing: CGFloat
    var lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + lineWidth, y: rect.height))
            path.addLine(to: CGPoint(x: x + lineWidth + rect.height, y: 0))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            path.closeSubpath()
            x += spacing
        }
        return path
    }
}

/// Горизонтальные полосы: так узкая колонка показывает прерванную сессию.
struct HorizontalStripes: Shape {
    var period: CGFloat
    var lineHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 0
        while y < rect.height {
            path.addRect(CGRect(x: 0, y: y, width: rect.width, height: min(lineHeight, rect.height - y)))
            y += period
        }
        return path
    }
}

/// Раздел «Учтённое время» под сеткой месяца.
struct TrackedTimeSection: View {
    @Environment(FocusEngine.self) private var focus
    let viewModel: CalendarViewModel

    var body: some View {
        let rows = viewModel.trackedRows
        let live = viewModel.showsLiveTracked ? focus.liveInterval : nil
        if !rows.isEmpty || live != nil {
            let liveMinutes = live.map { Int($0.end.timeIntervalSince($0.start) / 60) } ?? 0
            let count = rows.count + (live == nil ? 0 : 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.Calendar.trackedTime)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.label)
                    Spacer()
                    Text(L10n.Calendar.trackedTotal(
                        DateFormatting.duration(minutes: viewModel.trackedMinutes + liveMinutes),
                        L10n.Focus.sessions(count)
                    ))
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColors.textTertiary)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        Button { viewModel.openSession(row.id) } label: {
                            TrackedRowView(
                                title: row.title, time: row.time, duration: row.duration, kind: row.kind,
                                colorHex: row.colorHex, hasTask: row.hasTask,
                                status: row.isInterrupted ? (L10n.Focus.statusInterrupted, .warning) : nil
                            )
                        }
                        .buttonStyle(.plain)
                        if index < rows.count - 1 || live != nil {
                            Divider().overlay(AppColors.separator).padding(.leading, 58)
                        }
                    }
                    if let live {
                        Button(action: viewModel.openLiveSession) {
                            TrackedRowView(
                                title: focus.task?.title ?? L10n.Focus.focusSession,
                                time: viewModel.timeText(live.start) + " – " + viewModel.timeText(live.end) + " · " + FocusText.kind(live.kind),
                                duration: DateFormatting.duration(minutes: liveMinutes), kind: live.kind,
                                colorHex: focus.task?.list?.colorHex, hasTask: focus.task != nil,
                                status: (L10n.Calendar.inProgress, .accent)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}

private struct TrackedRowView: View {
    enum StatusStyle { case warning, accent }

    let title: String
    let time: String
    let duration: String
    let kind: TimeEntryKind
    let colorHex: String?
    let hasTask: Bool
    let status: (String, StatusStyle)?

    var body: some View {
        let style = colorHex.map { CategoryStyle(hex: $0) }
        HStack(spacing: 12) {
            Image(systemName: kind.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style?.tint ?? AppColors.accent)
                .frame(width: 32, height: 32)
                .background(style?.background ?? AppColors.accentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(hasTask ? AppColors.label : AppColors.textSecondary)
                    .lineLimit(1)
                Text(time)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(duration)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.label)
                if let status {
                    Text(status.0)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(status.1 == .warning ? AppColors.warningText : AppColors.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(status.1 == .warning ? AppColors.warningSoft : AppColors.accentSoft,
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
