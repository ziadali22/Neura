import SwiftUI

// MARK: - Custom Tab Bar (Liquid Glass morphing bar)
//
// The collapsed pill (a segmented control over the three tabs) lives inside a
// Liquid Glass capsule. Tapping the FAB morphs that capsule upward into the
// "add document" menu via `ExpandableGlassEffect`. The bar grows in height when
// expanded — that growth is intentional and matches the legacy card behaviour;
// `DashboardView` masks the resulting content shift with its dim overlay.

struct CustomTabBar: View {
    @Binding var selectedTab: AppCoordinator.Tab
    @Binding var isMenuOpen: Bool
    let onAction: (AppCoordinator.AddDocumentAction) -> Void
    var canUpload: Bool = true
    var onPaywallNeeded: () -> Void = {}
    var showCoachmarkHighlight: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewWidth: CGFloat?
    @State private var highlightPulse = false

    private let spring: Animation = .spring(response: 0.45, dampingFraction: 0.80)

    /// Height of the collapsed tab bar pill. Tune this single value to make the
    /// segmented control (and its glass capsule) taller or shorter.
    private let barHeight: CGFloat = 60

    // Order shown left→right in the bar.
    private let tabs: [AppCoordinator.Tab] = [.profile, .home, .docs]

    // MARK: - Add-document actions

    private struct ActionItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let action: AppCoordinator.AddDocumentAction
    }

    private let actions: [ActionItem] = [
        .init(icon: "scanAdd",  title: L10n.Documents.scan,         subtitle: L10n.Documents.AddDocument.scanSubtitle,  action: .scan),
        .init(icon: "imageAdd", title: L10n.Documents.uploadPhotos, subtitle: L10n.Documents.AddDocument.photoSubtitle, action: .photo),
        .init(icon: "fileAdd",  title: L10n.Documents.importFile,   subtitle: L10n.Documents.AddDocument.fileSubtitle,  action: .file),
    ]

    // MARK: - Body

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            morphingPill
            fab
        }
        .padding(.bottom, -8)
    }

    // MARK: - Morphing pill

    private var morphingPill: some View {
        ZStack {
            if let viewWidth {
                let progress: CGFloat = isMenuOpen ? 1 : 0
                let labelSize = CGSize(width: viewWidth, height: barHeight)
                let cornerRadius = labelSize.height / 2

                ExpandableGlassEffect(
                    alignment: .bottom,
                    progress: progress,
                    labelSize: labelSize,
                    cornerRadius: cornerRadius
                ) {
                    addDocsMenu
                        .frame(height: 420)
                } label: {
                    TabSegmentedControl(tabs: tabs, selectedTab: $selectedTab)
                        .frame(height: barHeight - 4)
                        .padding(.horizontal, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewWidth = $0 }
        .frame(height: viewWidth == nil ? barHeight : nil)
    }

    // MARK: - Expanded "add document" menu

    private var addDocsMenu: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                ForEach(actions) { item in
                    actionRow(item)
                }
            }
        }
        .padding(10)
        .frame(width: viewWidth)
        .onAppear {
            guard showCoachmarkHighlight else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                highlightPulse = true
            }
        }
        .onDisappear { highlightPulse = false }
    }

    private func actionRow(_ item: ActionItem) -> some View {
        Button {
            fire(item.action)
        } label: {
            HStack(spacing: 14) {
                Image(item.icon)
                    .renderingMode(.template)
                    .font(.title3)
                    .foregroundStyle(Color.accent)
                    .frame(width: 45, height: 45)
                    .background(
                        Color(hex: "E7E0D8").opacity(0.6),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                if showCoachmarkHighlight {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accent.opacity(highlightPulse ? 0.12 : 0.04))
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(item.title)
        .accessibilityHint(item.subtitle)
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            HapticManager.medium()
            if canUpload {
                isMenuOpen.toggle()
            } else {
                onPaywallNeeded()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(isMenuOpen ? 45 : 0))
                .animation(reduceMotion ? .easeInOut(duration: 0.22) : spring, value: isMenuOpen)
                .frame(width: 56, height: 56)
                .background(Color.accent)
                .clipShape(Circle())
                .shadow(color: Color.accent.opacity(0.18), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMenuOpen ? L10n.Common.close : L10n.Documents.addDocument)
    }

    // MARK: - Helpers

    private func fire(_ action: AppCoordinator.AddDocumentAction) {
        HapticManager.medium()
        isMenuOpen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onAction(action)
        }
    }
}

// MARK: - Tab segmented control

/// A `UISegmentedControl` driving the three tabs. Icons are tinted manually so
/// the active tab shows in the accent colour regardless of how the underlying
/// asset is authored; selection is also reinforced by the selected-segment pill.
private struct TabSegmentedControl: UIViewRepresentable {
    var tabs: [AppCoordinator.Tab]
    @Binding var selectedTab: AppCoordinator.Tab

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: Array(repeating: "", count: tabs.count))
        control.selectedSegmentIndex = index(of: selectedTab)
        control.selectedSegmentTintColor = UIColor(Color.backgroundCard)
        applyImages(to: control, selectedIndex: control.selectedSegmentIndex)
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didSelect(_:)),
            for: .valueChanged
        )
        // Hide the auto-inserted divider image views so only our glyphs show.
        DispatchQueue.main.async {
            for view in control.subviews.dropLast() where view is UIImageView {
                view.alpha = 0
            }
        }
        return control
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        let idx = index(of: selectedTab)
        if uiView.selectedSegmentIndex != idx {
            uiView.selectedSegmentIndex = idx
        }
        applyImages(to: uiView, selectedIndex: idx)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }

    // MARK: Internals

    private func index(of tab: AppCoordinator.Tab) -> Int {
        tabs.firstIndex(of: tab) ?? 0
    }

    private func applyImages(to control: UISegmentedControl, selectedIndex: Int) {
        for (i, tab) in tabs.enumerated() {
            control.setImage(image(for: tab, selected: i == selectedIndex), forSegmentAt: i)
        }
    }

    private func image(for tab: AppCoordinator.Tab, selected: Bool) -> UIImage? {
        let name = selected ? tab.selectedIcon : tab.icon
        let color = UIColor(selected ? Color.accent : Color.textSecondary)
        return UIImage(named: name)?
            .withRenderingMode(.alwaysTemplate)
            .withTintColor(color, renderingMode: .alwaysOriginal)
    }

    final class Coordinator: NSObject {
        var parent: TabSegmentedControl
        init(parent: TabSegmentedControl) { self.parent = parent }

        @objc func didSelect(_ control: UISegmentedControl) {
            let i = control.selectedSegmentIndex
            guard parent.tabs.indices.contains(i) else { return }
            parent.selectedTab = parent.tabs[i]
        }
    }
}

// MARK: - Glass button style

struct PlainGlassButtonEffect<S: Shape>: ButtonStyle {
    var shape: S
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(.regular.interactive(), in: shape)
    }
}

// MARK: - Expandable glass effect

/// Morphs a small `label` (the collapsed pill) into a larger `content` view
/// (the expanded menu) as `progress` animates 0 → 1, with a liquid-glass blur.
struct ExpandableGlassEffect<Content: View, Label: View>: View, Animatable {
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label

    @State private var contentSize: CGSize = .zero

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GlassEffectContainer {
            let widthDiff = contentSize.width - labelSize.width
            let heightDiff = contentSize.height - labelSize.height
            let rWidth = widthDiff * contentOpacity
            let rHeight = heightDiff * contentOpacity

            ZStack(alignment: alignment) {
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: labelSize.width + rWidth,
                           height: labelSize.height + rHeight)

                label
                    .compositingGroup()
                    .blur(radius: 14 * blurProgress)
                    .opacity(1 - labelOpacity)
                    .frame(width: labelSize.width, height: labelSize.height)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: cornerRadius))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
        .scaleEffect(x: 1 - (blurProgress * 0.5),
                     y: 1 + (blurProgress * 0.5),
                     anchor: scaleAnchor)
        .offset(y: offset * blurProgress)
    }

    private var labelOpacity: CGFloat { min(progress / 0.35, 1) }
    private var contentOpacity: CGFloat { max(progress - 0.35, 0) }

    private var contentScale: CGFloat {
        guard contentSize.width > 0, contentSize.height > 0 else { return 1 }
        let minAspectScale = min(labelSize.width / contentSize.width,
                                 labelSize.height / contentSize.height)
        return minAspectScale + (1 - minAspectScale) * progress
    }

    private var blurProgress: CGFloat {
        progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }

    private var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing: return -75
        case .top, .topTrailing, .topLeading: return 75
        default: return -10
        }
    }

    private var scaleAnchor: UnitPoint {
        switch alignment {
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}

// MARK: - Tab metadata

extension AppCoordinator.Tab: CaseIterable, Identifiable {
    public var id: Int { rawValue }
    public static var allCases: [AppCoordinator.Tab] { [.profile, .home, .docs] }

    var label: String {
        switch self {
        case .profile: "Profile"
        case .home:    "Home"
        case .docs:    "Docs"
        }
    }

    var icon: String {
        switch self {
        case .profile: "profileUnselected"
        case .home:    "homeUnselected"
        case .docs:    "fileUnselected"
        }
    }

    var selectedIcon: String {
        switch self {
        case .profile: "profileSelected"
        case .home:    "homeSelected"
        case .docs:    "fileSelected"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack(alignment: .bottom) {
        Color.backgroundPrimary.ignoresSafeArea()
        CustomTabBar(
            selectedTab: .constant(.home),
            isMenuOpen: .constant(false),
            onAction: { _ in }
        )
        .padding(.horizontal, 20)
    }
}
