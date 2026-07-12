import SwiftUI

struct AddSpaceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedColorHex = AddSpaceSheet.colorPalette[0]

    let onCreate: (String, String) -> Void

    static let colorPalette = ["FF5A00", "3498DB", "9B59B6", "27AE60", "E74C3C", "1ABC9C"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.Profile.Spaces.namePlaceholder, text: $name)
                }

                Section {
                    HStack(spacing: 12) {
                        ForEach(Self.colorPalette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.textPrimary, lineWidth: selectedColorHex == hex ? 2 : 0)
                                        .padding(-3)
                                )
                                .onTapGesture { selectedColorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle(L10n.Profile.Spaces.addSpaceTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.create) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed, selectedColorHex)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
