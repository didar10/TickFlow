import Observation
import SwiftUI

/// Какой черновик сейчас открыт в панели быстрого создания и кого известить о закрытии.
@MainActor
@Observable
final class QuickEditorHost {
    private(set) var editor: TaskEditorViewModel?
    /// Панель уезжает вниз; черновик убирается, когда анимация закончится.
    private(set) var isClosing = false
    @ObservationIgnored private var onClose: (() -> Void)?

    func show(_ editor: TaskEditorViewModel, onClose: @escaping () -> Void) {
        self.onClose = onClose
        isClosing = false
        self.editor = editor
    }

    /// Запускает закрытие: панель и клавиатура уезжают вместе.
    func close() {
        guard editor != nil, !isClosing else { return }
        isClosing = true
    }

    /// Вызывается панелью после анимации закрытия.
    func finishClose() {
        guard editor != nil else { return }
        editor = nil
        isClosing = false
        let onClose = onClose
        self.onClose = nil
        onClose?()
    }
}

/// Панель быстрого создания задачи поверх всего приложения.
///
/// Это не системный `.sheet`: лист держит клавиатуру до конца своей анимации, и она
/// подбрасывает его уже после появления. Панель стоит в обычной иерархии, поэтому фокус
/// ставится сразу, а сама панель прижата к клавиатуре и движется вместе с ней —
/// и при открытии, и при закрытии.
struct QuickTaskPanel: View {
    let host: QuickEditorHost
    @State private var dragOffset: CGFloat = 0
    @State private var panelHeight: CGFloat = 0

    /// Длительность близка к анимации клавиатуры, чтобы панель не отставала от неё.
    private static let closeDuration = 0.3

    var body: some View {
        ZStack(alignment: .bottom) {
            if let editor = host.editor {
                Color.black.opacity(host.isClosing ? 0 : 0.28)
                    .ignoresSafeArea()
                    .animation(.smooth(duration: Self.closeDuration), value: host.isClosing)
                    .onTapGesture(perform: host.close)
                    .transition(.opacity)
                    .accessibilityLabel(L10n.Common.close)
                    .accessibilityAddTraits(.isButton)

                TaskEditorView(viewModel: editor, container: .quick, onClose: host.close)
                    .frame(maxWidth: .infinity)
                    .background {
                        UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16, style: .continuous)
                            .fill(AppColors.surface)
                            .shadow(color: .black.opacity(0.08), radius: 12, y: -6)
                            .ignoresSafeArea(edges: .bottom)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
                    .offset(y: dragOffset)
                    .gesture(dismissDrag)
                    .allowsHitTesting(!host.isClosing)
                    // Уход вниз анимируется смещением, поэтому при удалении переход не нужен.
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .identity))
                    .id(ObjectIdentifier(editor))
            }
        }
        .animation(.smooth(duration: 0.3), value: host.editor.map(ObjectIdentifier.init))
        .onChange(of: host.isClosing) { _, closing in
            if closing { animateClose() }
        }
        .onChange(of: host.editor == nil) { dragOffset = 0 }
    }

    /// Клавиатура начинает скрываться в том же кадре, что и панель уезжает вниз.
    /// Панель прижата к клавиатуре, а смещение уводит её за край экрана — они движутся вместе.
    private func animateClose() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.smooth(duration: Self.closeDuration)) {
            dragOffset = panelHeight + 80
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.closeDuration))
            host.finishClose()
        }
    }

    /// Смахивание вниз закрывает панель, как системный лист.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { dragOffset = max(0, $0.translation.height) }
            .onEnded { value in
                if value.translation.height > 60 || value.predictedEndTranslation.height > 160 {
                    host.close()
                } else {
                    withAnimation(.smooth(duration: 0.2)) { dragOffset = 0 }
                }
            }
    }
}
