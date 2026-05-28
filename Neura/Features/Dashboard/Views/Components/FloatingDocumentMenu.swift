import SwiftUI

// MARK: - Floating Document Menu

struct FloatingDocumentMenu: View {
    @Binding var isPresented: Bool
    let onAction: (AppCoordinator.AddDocumentAction) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    // MARK: - Menu Items

    private struct MenuItem {
        let icon: String
        let title: String
        let subtitle: String
        let action: AppCoordinator.AddDocumentAction
    }

    private let items: [MenuItem] = [
        .init(icon: "scanAdd",  title: "Scan Document",      subtitle: "Use camera to scan pages",          action: .scan),
        .init(icon: "imageAdd", title: "Upload from Photos", subtitle: "Choose an image from your library", action: .photo),
        .init(icon: "fileAdd",  title: "Import File",        subtitle: "Select a PDF or image file",        action: .file),
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen backdrop — card/X button render above it inside the same ZStack
            Color.black.opacity(appear ? 0.30 : 0)
                .ignoresSafeArea()
                .onTapGesture { collapse() }
                .accessibilityLabel("Close menu")
                .accessibilityAddTraits(.isButton)

            // Card + X button row
            HStack(alignment: .bottom, spacing: 16) {
                card
                    .opacity(appear ? 1 : 0)
                    .blur(radius: appear ? 0 : 4)
                    .scaleEffect(appear ? 1 : 0.88, anchor: .bottomLeading)
                    .offset(y: appear ? 0 : 20)

                closeButton
                    .scaleEffect(appear ? 1 : 0.5)
                    .opacity(appear ? 1 : 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
            .safeAreaPadding(.bottom)
        }
        .animation(
            reduceMotion
                ? .easeInOut(duration: 0.2)
                : .spring(response: 0.44, dampingFraction: 0.78),
            value: appear
        )
        .onAppear { animateIn() }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Divider().padding(.leading, 72)
                }
                menuRow(for: item)
            }
        }
        .background(Color.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 6)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            HapticManager.medium()
            collapse()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accent)
                .clipShape(Circle())
                .shadow(color: Color.accent.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close menu")
    }

    // MARK: - Row

    private func menuRow(for item: MenuItem) -> some View {
        Button {
            HapticManager.medium()
            collapseAndFire(item.action)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(hex: "E7E0D8").opacity(0.6))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(item.icon)
                            .font(.system(size: 23))
                            .foregroundStyle(Color.accent)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                    Text(item.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(item.title)
        .accessibilityHint(item.subtitle)
    }

    // MARK: - Animation Helpers

    private func animateIn() {
        if reduceMotion {
            appear = true
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                appear = true
            }
        }
    }

    private func collapse() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            appear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isPresented = false
        }
    }

    private func collapseAndFire(_ action: AppCoordinator.AddDocumentAction) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            appear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
            onAction(action)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack(alignment: .bottom) {
        Color.backgroundPrimary.ignoresSafeArea()
        FloatingDocumentMenu(isPresented: .constant(true), onAction: { _ in })
    }
}
