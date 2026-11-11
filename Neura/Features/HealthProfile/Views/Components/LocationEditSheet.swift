import SwiftUI

struct LocationEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationDetector = LocationDetector()
    @State private var city: String
    @State private var country: String
    @FocusState private var focusedField: Field?
    let onSave: (String, String) -> Void

    private enum Field: Hashable {
        case city
        case country
    }

    init(location: String, onSave: @escaping (String, String) -> Void) {
        let parts = UserLocationStore.parts(from: location)
        _city = State(initialValue: parts.city)
        _country = State(initialValue: parts.country)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: save) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.surfaceDark)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Common.done)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(L10n.HealthProfile.editFormat(L10n.HealthProfile.location))
                            .font(.displayXL)
                            .foregroundStyle(Color.textPrimary)

                        detectButton

                        locationField(
                            title: L10n.Onboarding.Location.city,
                            placeholder: L10n.Onboarding.Location.cityPlaceholder,
                            icon: "building.2.fill",
                            text: $city,
                            field: .city,
                            submitLabel: .next
                        )

                        locationField(
                            title: L10n.Onboarding.Location.country,
                            placeholder: L10n.Onboarding.Location.countryPlaceholder,
                            icon: "globe",
                            text: $country,
                            field: .country,
                            submitLabel: .done
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color.backgroundPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.done) { focusedField = nil }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
    }

    private func save() {
        onSave(city, country)
        dismiss()
    }

    private func detectLocation() {
        focusedField = nil
        locationDetector.detect { detectedCity, detectedCountry in
            city = detectedCity
            country = detectedCountry
        }
    }
}

private extension LocationEditSheet {
    var detectButton: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: detectLocation) {
                HStack(spacing: 12) {
                    if locationDetector.isDetecting {
                        ProgressView()
                            .tint(Color.accent)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.accent)
                    }
                    Text(locationDetector.isDetecting
                         ? L10n.Onboarding.Location.detecting
                         : L10n.Onboarding.Location.detect)
                        .font(.bodyL)
                        .foregroundStyle(Color.accent)
                    Spacer()
                    if !locationDetector.isDetecting {
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .padding(16)
                .background(Color.accent.opacity(0.07))
                .clipShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(locationDetector.isDetecting)

            if let error = locationDetector.errorMessage {
                Text(error)
                    .font(.captionS)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func locationField(
        title: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        field: Field,
        submitLabel: SubmitLabel
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headingXS)
                .foregroundStyle(Color.textPrimary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textTertiary)

                TextField(placeholder, text: text)
                    .font(.bodyL)
                    .focused($focusedField, equals: field)
                    .submitLabel(submitLabel)
                    .onSubmit { advance(from: field) }
            }
            .padding(16)
            .background(Color.surfaceWhite)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private func advance(from field: Field) {
        switch field {
        case .city: focusedField = .country
        case .country: focusedField = nil
        }
    }
}

#Preview {
    LocationEditSheet(location: "Cairo, Egypt") { _, _ in }
        .background(Color.backgroundPrimary)
}
