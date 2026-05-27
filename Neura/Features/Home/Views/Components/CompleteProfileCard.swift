import SwiftUI

struct CompleteProfileCard: View {
    @StateObject private var viewModel = HealthProfileViewModel()
    @State private var arrowBounce = false

    var onTap: (() -> Void)?

    private var missingFields: [String] {
        let data = viewModel.profile.generalData
        var fields: [String] = []
        if data.fullName.isEmpty { fields.append("name") }
        if data.dateOfBirth.isEmpty { fields.append("date of birth") }
        if data.gender.isEmpty { fields.append("gender") }
        if data.height.isEmpty { fields.append("height") }
        if data.weight.isEmpty { fields.append("weight") }
        if data.bloodType.isEmpty { fields.append("blood type") }
        if data.insuranceStatus.isEmpty { fields.append("insurance") }
        return fields
    }

    private var subtitle: String {
        let fields = missingFields
        guard !fields.isEmpty else { return "Your profile is complete!" }
        let display = fields.prefix(3)
        let joined = display.map { $0.capitalized }.joined(separator: ", ")
        if fields.count > 3 {
            return "Add your \(joined) and \(fields.count - 3) more"
        } else {
            return "Add your \(joined)"
        }
    }

    var isComplete: Bool { missingFields.isEmpty }

    var body: some View {
        if !isComplete {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    arrowBounce.toggle()
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    onTap?()
                }
            } label: {
                ProfileCardContent(subtitle: subtitle, arrowBounce: arrowBounce)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

// MARK: - Card Content

private struct ProfileCardContent: View {
    let subtitle: String
    let arrowBounce: Bool
    @State private var lineAnimation = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.accent, Color.white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: lineAnimation ? 186 : 0, height: 1)
                .offset(x: 73, y: 1)
                .animation(.easeOut(duration: 0.8).delay(0.5), value: lineAnimation)

                HStack(spacing: 13) {
                    Image("complete_profile")
                        .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Home.completeProfile)
                            .font(.headingXS)
                            .foregroundStyle(Color.textPrimary)

                        Text(subtitle)
                            .font(.bodyS)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.surfaceDark)
                        .clipShape(Circle())
                        .scaleEffect(arrowBounce ? 0.9 : 1.0)
                        .offset(x: arrowBounce ? 5 : 0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: arrowBounce)
                }
                .padding(16)
                .frame(height: 90)
                .background(Color.surfaceWhite)
                .clipShape(.rect(cornerRadius: 24))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                lineAnimation = true
            }
        }
    }
}

#Preview {
    CompleteProfileCard(onTap: {})
        .padding()
}
