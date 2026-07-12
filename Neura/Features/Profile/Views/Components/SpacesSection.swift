import SwiftUI

struct SpacesSection: View {
    @StateObject private var activeSpaceManager = ActiveSpaceManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showAddSpace = false
    @State private var showPaywall = false
    @State private var spaceToRemove: Space?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(activeSpaceManager.visibleSpaces) { space in
                    SpaceChip(
                        space: space,
                        isActive: space.id == activeSpaceManager.currentSpaceID,
                        onTap: { activeSpaceManager.setActive(space.id) },
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
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.surfaceWhite)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showAddSpace) {
            AddSpaceSheet { name, colorHex in
                activeSpaceManager.createSpace(name: name, colorHex: colorHex)
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
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
}

private struct SpaceChip: View {
    let space: Space
    let isActive: Bool
    let onTap: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color(hex: space.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(space.name.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                )
                .overlay(
                    Circle()
                        .stroke(Color.accent, lineWidth: isActive ? 2 : 0)
                        .padding(-3)
                )

            Text(space.name)
                .font(.captionS)
                .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label(L10n.Profile.Spaces.removeTitle, systemImage: "trash")
                }
            }
        }
    }
}
