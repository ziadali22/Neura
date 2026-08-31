import SwiftUI
import PhotosUI

struct SpacesSection: View {
    var onProfileSwitched: (() -> Void)? = nil
    /// Fired immediately after the active space changes so sibling rows
    /// (Growth, etc.) can update even if the parent is not observing the manager.
    var onSpaceChanged: (() -> Void)? = nil

    @EnvironmentObject private var router: ProfileRouter
    @StateObject private var activeSpaceManager = ActiveSpaceManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showAddSpace = false
    @State private var showPaywall = false
    @State private var spaceToRemove: Space?
    @State private var editingSpace: Space?
    @State private var pendingSwitchTarget: Space?
    @State private var pendingSwitchToast = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(activeSpaceManager.visibleSpaces) { space in
                    SpaceChip(
                        space: space,
                        isActive: space.id == activeSpaceManager.currentSpaceID,
                        onTap: { requestSwitch(to: space) },
                        onEdit: { editingSpace = space },
                        onRemove: space.isDefault ? nil : { spaceToRemove = space },
                        onPickPhoto: { image in
                            activeSpaceManager.updateSpace(id: space.id, name: space.name, avatarImage: image)
                        }
                    )
                }

                Button {
                    HapticManager.medium()
                    if subscriptionManager.canCreateSpace {
                        showAddSpace = true
                    } else {
                        AnalyticsManager.shared.track(.spaceAddBlocked, properties: [
                            "space_count": activeSpaceManager.visibleSpaces.count
                        ])
                        showPaywall = true
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.accent)
                            .frame(width: SpaceChip.avatarSize, height: SpaceChip.avatarSize)
                            .background(Color.backgroundCard)
                            .clipShape(Circle())

                        Text(L10n.Common.add)
                            .font(.captionS)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showAddSpace) {
            AddSpaceSheet { name, image, details in
                let space = activeSpaceManager.createSpace(name: name, avatarImage: image, relationship: details.relationship)
                AnalyticsManager.shared.track(.spaceCreated, properties: [
                    "relationship": details.relationship ?? "none",
                    "space_count": activeSpaceManager.visibleSpaces.count,
                    "has_avatar": image != nil
                ])
                HealthProfileViewModel.seedInitialProfile(
                    for: space.id, fullName: name, dateOfBirth: details.dateOfBirth, gender: details.gender,
                    bloodType: details.bloodType, height: details.height, weight: details.weight
                )
                // Send the parent straight into this person's Health Profile so they
                // can fill in conditions, medications, allergies etc. right away,
                // using the existing full-featured screens rather than a duplicate
                // in this popup.
                switchTo(space.id) { router.push(.healthProfile) }
            }
        }
        .sheet(item: $editingSpace) { space in
            AddSpaceSheet(mode: .edit(space)) { name, image, _ in
                activeSpaceManager.updateSpace(id: space.id, name: name, avatarImage: image)
            }
        }
        .sheet(item: $pendingSwitchTarget, onDismiss: {
            guard pendingSwitchToast else { return }
            pendingSwitchToast = false
            onProfileSwitched?()
        }) { target in
            if let current = activeSpaceManager.spaces.first(where: { $0.id == activeSpaceManager.currentSpaceID }) {
                SwitchAccountConfirmSheet(
                    currentSpace: current,
                    targetSpace: target,
                    onCancel: { pendingSwitchTarget = nil },
                    onConfirm: {
                        performSwitch(to: target.id)
                        pendingSwitchToast = true
                        pendingSwitchTarget = nil
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager, source: "space_limit")
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
                    AnalyticsManager.shared.track(.spaceArchived, properties: [
                        "space_count": activeSpaceManager.visibleSpaces.count
                    ])
                }
                spaceToRemove = nil
            }
            Button(L10n.Common.cancel, role: .cancel) { spaceToRemove = nil }
        } message: {
            Text(L10n.Profile.Spaces.removeMessage)
        }
    }

    private func requestSwitch(to space: Space) {
        guard space.id != activeSpaceManager.currentSpaceID else { return }
        HapticManager.selection()
        pendingSwitchTarget = space
    }

    /// Instant switch used after the confirm sheet's in-sheet loader (or when
    /// creating a new account and jumping straight into Health Profile).
    private func performSwitch(to spaceID: UUID) {
        guard spaceID != activeSpaceManager.currentSpaceID else { return }
        let fromID = activeSpaceManager.currentSpaceID
        activeSpaceManager.setActive(spaceID)
        onSpaceChanged?()
        AnalyticsManager.shared.track(.spaceSwitched, properties: [
            "from_default": fromID == ActiveSpaceManager.defaultSpaceID,
            "to_default": spaceID == ActiveSpaceManager.defaultSpaceID,
            "space_count": activeSpaceManager.visibleSpaces.count
        ])
    }

    private func switchTo(_ spaceID: UUID, completion: (() -> Void)? = nil) {
        performSwitch(to: spaceID)
        completion?()
    }
}

private struct SpaceChip: View {
    let space: Space
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onRemove: (() -> Void)?
    let onPickPhoto: (UIImage) -> Void

    static let avatarSize: CGFloat = 100

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imagePendingCrop: PickedImage?

    var body: some View {
        VStack(spacing: 6) {
            avatarView
                .frame(width: Self.avatarSize, height: Self.avatarSize)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.accent, lineWidth: isActive ? 3 : 0)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            // Only the account you're currently in offers the shortcut, so the row
            // stays a switcher; the others are still editable via the long-press menu.
            .overlay(alignment: .bottomTrailing) {
                if isActive { photoBadge }
            }

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
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    imagePendingCrop = PickedImage(image: uiImage)
                }
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(item: $imagePendingCrop) { wrapped in
            AvatarCropView(
                image: wrapped.image,
                onCancel: { imagePendingCrop = nil },
                onConfirm: { cropped in
                    onPickPhoto(cropped)
                    imagePendingCrop = nil
                }
            )
        }
    }

    private var photoBadge: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accent, in: Circle())
                .overlay(Circle().stroke(Color.backgroundPrimary, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Profile.Spaces.changePhoto)
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
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }
}

private struct PickedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
