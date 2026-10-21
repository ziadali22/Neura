import SwiftUI

struct GrowthWeightPickerSheet: View {
    @State private var kilograms: Int
    @State private var grams: Int
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss

    init(currentKg: Double, onSave: @escaping (Double) -> Void) {
        let parts = GrowthEntry.splitWeight(currentKg)
        _kilograms = State(initialValue: parts.kilograms)
        _grams = State(initialValue: parts.grams)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: save) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.accent)
                        .clipShape(Circle())
                }
                .accessibilityLabel(L10n.Common.save)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.HealthProfile.editFormat(L10n.Growth.weight))
                    .font(.displayXL)
                    .foregroundStyle(Color.textPrimary)
                    .padding(.horizontal, 20)

                Text(GrowthEntry.formatWeight(totalKg))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Color.accent)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: totalKg)
                    .accessibilityLabel(L10n.Growth.weight)
                    .accessibilityValue(GrowthEntry.formatWeight(totalKg))

                HStack(spacing: 0) {
                    Picker("", selection: $kilograms) {
                        ForEach(GrowthEntry.weightKilogramRange, id: \.self) { value in
                            Text("\(value) kg")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .accessibilityLabel("kg")

                    Picker("", selection: $grams) {
                        ForEach(GrowthEntry.weightGramValues, id: \.self) { value in
                            Text("\(value) g")
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .accessibilityLabel("g")
                }
                .frame(height: 200)
                .padding(.horizontal, 8)
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 20))
                .padding(.horizontal, 20)
            }
            .padding(.top, 20)

            Spacer()
        }
        .background(Color.backgroundPrimary)
    }

    private var totalKg: Double {
        GrowthEntry.combineWeight(kilograms: kilograms, grams: grams)
    }

    private func save() {
        onSave(totalKg)
        dismiss()
    }
}

#Preview {
    GrowthWeightPickerSheet(currentKg: 2.4) { _ in }
}
