import SwiftUI

struct SwitchAccountConfirmSheet: View {
    let currentSpace: Space
    let targetSpace: Space
    let onCancel: () -> Void
    /// Called after the in-sheet loading moment — parent should activate the
    /// target space and dismiss this sheet.
    let onConfirm: () -> Void

    @State private var isLoading = false
    @State private var sheetHeight: CGFloat = 320

    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .top, spacing: 20) {
                labeledAvatar(for: currentSpace, ringed: true)

                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(height: Self.avatarSize)

                labeledAvatar(for: targetSpace, ringed: false)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                Text(L10n.Profile.Spaces.confirmSwitchTitleFormat(targetSpace.name))
                    .font(.headingS)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(L10n.Profile.Spaces.confirmSwitchMessageFormat(targetSpace.name))
                    .font(.bodyS)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.accent)
                        .scaleEffect(1.15)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 10) {
                        Button(action: onCancel) {
                            Text(L10n.Common.cancel)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.backgroundCard)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Button(action: confirmTapped) {
                            Text(L10n.Common.confirm)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.textPrimary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
            .frame(minHeight: 52)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .background(Color.backgroundPrimary)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height + proxy.safeAreaInsets.bottom
        } action: { newHeight in
            guard abs(sheetHeight - newHeight) > 1 else { return }
            sheetHeight = newHeight
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Color.backgroundPrimary)
        .interactiveDismissDisabled(isLoading)
    }

    private func confirmTapped() {
        guard !isLoading else { return }
        isLoading = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            onConfirm()
        }
    }

    private static let avatarSize: CGFloat = 96

    private func labeledAvatar(for space: Space, ringed: Bool) -> some View {
        VStack(spacing: 8) {
            avatarImage(for: space)
                .frame(width: Self.avatarSize, height: Self.avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.accent, lineWidth: ringed ? 3 : 0)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)

            Text(space.name)
                .font(ringed ? .headingXS : .bodyL)
                .foregroundStyle(ringed ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
        }
        .frame(width: Self.avatarSize)
    }

    @ViewBuilder
    private func avatarImage(for space: Space) -> some View {
        if let filename = space.avatarFilename, let image = AccountAvatarStore.shared.loadImage(filename: filename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color(hex: space.colorHex))
                .overlay(
                    Text(space.name.prefix(1).uppercased())
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }
}
