import SwiftUI
import PhotosUI

// MARK: - Card Background Model

struct CardBackground: Identifiable, Equatable, Codable {
    let id: String
    let type: BackgroundType

    enum BackgroundType: Equatable, Codable {
        case image(String)
        case customPhoto(String) // filename stored on disk
        case gradient(GradientDef)
    }

    struct GradientDef: Equatable, Codable {
        let colors: [String]
        let startPoint: UnitPointCodable
        let endPoint: UnitPointCodable
    }

    struct UnitPointCodable: Equatable, Codable {
        let x: CGFloat
        let y: CGFloat
        var unitPoint: UnitPoint { UnitPoint(x: x, y: y) }
    }

    // MARK: - Presets

    static let imageBackgrounds: [CardBackground] = [
        "bg11", "bg12", "bg15", "bg16", "bg17",
        "bg20", "bg21", "bg23", "bg24", "bg25"
    ].map { .init(id: $0, type: .image($0)) }

    static let gradientBackgrounds: [CardBackground] = [
        .init(id: "midnight", type: .gradient(.init(
            colors: ["1A1A2E", "16213E", "0F3460"],
            startPoint: .init(x: 0, y: 0), endPoint: .init(x: 1, y: 1)
        ))),
        .init(id: "ember", type: .gradient(.init(
            colors: ["FF5A00", "C62828"],
            startPoint: .init(x: 0, y: 0), endPoint: .init(x: 1, y: 1)
        ))),
        .init(id: "ocean", type: .gradient(.init(
            colors: ["0D47A1", "1565C0", "42A5F5"],
            startPoint: .init(x: 0, y: 0), endPoint: .init(x: 0.5, y: 1)
        ))),
        .init(id: "forest", type: .gradient(.init(
            colors: ["1B5E20", "2E7D32", "66BB6A"],
            startPoint: .init(x: 0, y: 0), endPoint: .init(x: 1, y: 1)
        ))),
        .init(id: "dusk", type: .gradient(.init(
            colors: ["4A148C", "7B1FA2", "CE93D8"],
            startPoint: .init(x: 0, y: 0), endPoint: .init(x: 0.5, y: 1)
        ))),
        .init(id: "charcoal", type: .gradient(.init(
            colors: ["212121", "424242", "616161"],
            startPoint: .init(x: 0, y: 0), endPoint: .init(x: 1, y: 1)
        ))),
    ]

    static let allPresets: [CardBackground] = imageBackgrounds + gradientBackgrounds

    static let `default` = imageBackgrounds.first!

    // MARK: - Persistence

    private static let storageKey = "selected_card_background"

    static func saved() -> CardBackground {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let bg = try? JSONDecoder().decode(CardBackground.self, from: data) else {
            return .default
        }
        return bg
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: CardBackground.storageKey)
        }
    }

    // MARK: - Custom Photo Storage

    static var customPhotosDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CardBackgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func saveCustomPhoto(_ image: UIImage) -> CardBackground? {
        let id = UUID().uuidString
        let filename = "\(id).jpg"
        let url = customPhotosDirectory.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: url)
            return CardBackground(id: id, type: .customPhoto(filename))
        } catch {
            return nil
        }
    }

    static func loadCustomPhotos() -> [CardBackground] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: customPhotosDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "jpg" }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return dateA > dateB
            }
            .map { url in
                let filename = url.lastPathComponent
                let id = url.deletingPathExtension().lastPathComponent
                return CardBackground(id: id, type: .customPhoto(filename))
            }
    }

    static func deleteCustomPhoto(_ bg: CardBackground) {
        guard case .customPhoto(let filename) = bg.type else { return }
        let url = customPhotosDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    func customPhotoURL() -> URL? {
        guard case .customPhoto(let filename) = type else { return nil }
        return CardBackground.customPhotosDirectory.appendingPathComponent(filename)
    }
}

// MARK: - Background View

struct CardBackgroundView: View {
    let background: CardBackground
    let height: CGFloat

    var body: some View {
        switch background.type {
        case .image(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(height: height)

        case .customPhoto(let filename):
            let url = CardBackground.customPhotosDirectory.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
            } else {
                Color.surfaceDark
                    .frame(height: height)
            }

        case .gradient(let def):
            LinearGradient(
                colors: def.colors.map { Color(hex: $0) },
                startPoint: def.startPoint.unitPoint,
                endPoint: def.endPoint.unitPoint
            )
            .frame(height: height)
        }
    }
}

// MARK: - Picker Sheet

struct CardBackgroundPickerSheet: View {
    @Binding var selected: CardBackground
    @Environment(\.dismiss) private var dismiss

    @State private var customPhotos: [CardBackground] = []
    @State private var selectedPhotoItem: PhotosPickerItem?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.textTertiary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            Text("Card Background")
                .font(.headingS)
                .foregroundColor(.textPrimary)
                .padding(.top, 16)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: Custom Photos
                    sectionHeader("Your Photos")

                    LazyVGrid(columns: columns, spacing: 12) {
                        // Upload button
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.accent)
                                Text("Upload")
                                    .font(.captionS)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .background(Color.surfaceWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            )
                        }

                        ForEach(customPhotos) { bg in
                            backgroundCell(bg, deletable: true)
                        }
                    }

                    // MARK: Presets
                    sectionHeader("Presets")

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CardBackground.imageBackgrounds) { bg in
                            backgroundCell(bg)
                        }
                    }

                    // MARK: Gradients
                    sectionHeader("Gradients")

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CardBackground.gradientBackgrounds) { bg in
                            backgroundCell(bg)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color.backgroundPrimary)
        .onAppear { customPhotos = CardBackground.loadCustomPhotos() }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let bg = CardBackground.saveCustomPhoto(image) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        customPhotos.insert(bg, at: 0)
                        selected = bg
                        bg.save()
                    }
                }
                selectedPhotoItem = nil
            }
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.textTertiary)
            .textCase(.uppercase)
    }

    private func backgroundCell(_ bg: CardBackground, deletable: Bool = false) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = bg
                bg.save()
            }
        } label: {
            CardBackgroundView(background: bg, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            selected.id == bg.id ? Color.accent : Color.clear,
                            lineWidth: 3
                        )
                )
                .overlay(alignment: .bottomTrailing) {
                    if selected.id == bg.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.accent).padding(2))
                            .padding(8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if deletable {
                        Button {
                            deleteCustomPhoto(bg)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white, .black.opacity(0.6))
                                .padding(6)
                        }
                    }
                }
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func deleteCustomPhoto(_ bg: CardBackground) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            customPhotos.removeAll { $0.id == bg.id }
            CardBackground.deleteCustomPhoto(bg)
            if selected.id == bg.id {
                selected = .default
                CardBackground.default.save()
            }
        }
    }
}

#Preview {
    CardBackgroundPickerSheet(selected: .constant(.default))
}
