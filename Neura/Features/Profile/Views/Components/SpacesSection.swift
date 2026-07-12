import SwiftUI

struct SpacesSection: View {
    @StateObject private var activeSpaceManager = ActiveSpaceManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showAddSpace = false
    @State private var showPaywall = false
    @State private var spaceToRemove: Space?
    @State private var editingSpace: Space?
    @State private var isSwitching = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(activeSpaceManager.visibleSpaces) { space in
                    SpaceChip(
                        space: space,
                        isActive: space.id == activeSpaceManager.currentSpaceID,
                        onTap: { switchTo(space.id) },
                        onEdit: { editingSpace = space },
                        onRemove: space.isDefault ? nil : { spaceToRemove = space }
                    )
                }

                Button {
                    if subscriptionManager.canCreateSpace {
                        showAddSpace = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 60, height: 60)
                        .background(Color.surfaceWhite)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(Color.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showAddSpace) {
            AddSpaceSheet { name, image in
                activeSpaceManager.createSpace(name: name, avatarImage: image)
            }
        }
        .sheet(item: $editingSpace) { space in
            AddSpaceSheet(mode: .edit(space)) { name, image in
                activeSpaceManager.updateSpace(id: space.id, name: name, avatarImage: image)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
        .fullScreenCover(isPresented: $isSwitching) {
            ZStack {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .tint(Color.accent)
                    .scaleEffect(1.3)
            }
        }
        .alert(
            L10n.Profile.Spaces.removeTitle,
            isPresented: Binding(
                get: { spaceToRemove != nil },
                set: { if !$0 { spaceToRemove = nil } }
            )
        ) {
            Button(L10n.Common.delete, role: .destructive) {
                if let space = spaceToRemove {
                    activeSpaceManager.archiveSpace(id: space.id)
                }
                spaceToRemove = nil
            }
            Button(L10n.Common.cancel, role: .cancel) { spaceToRemove = nil }
        } message: {
            Text(L10n.Profile.Spaces.removeMessage)
        }
    }

    /// Brief (~0.5s) perceived-loading moment before the switch takes effect.
    /// The switch itself is instant (in-memory filter) — this is pure polish.
    private func switchTo(_ spaceID: UUID) {
        guard spaceID != activeSpaceManager.currentSpaceID else { return }
        isSwitching = true
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            activeSpaceManager.setActive(spaceID)
            isSwitching = false
        }
    }
}

private struct SpaceChip: View {
    let space: Space
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            avatarView
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.backgroundPrimary, lineWidth: isActive ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color.accent, lineWidth: isActive ? 2 : 0)
                        .padding(-3)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)

            Text(space.name)
                .font(.captionS)
                .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button(action: onEdit) {
                Label(L10n.Profile.Spaces.editSpaceTitle, systemImage: "pencil")
            }
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label(L10n.Profile.Spaces.removeTitle, systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let filename = space.avatarFilename, let image = AccountAvatarStore.shared.loadImage(filename: filename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Circle()
                .fill(Color(hex: space.colorHex))
                .overlay(
                    Text(space.name.prefix(1).uppercased())
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }
}
