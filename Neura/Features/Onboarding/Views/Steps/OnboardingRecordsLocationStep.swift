import SwiftUI

struct OnboardingRecordsLocationStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Data

    private struct Option: Identifiable {
        let id = UUID()
        let label: String
        let imageName: String
    }

    private let options: [Option] = [
        .init(label: L10n.Onboarding.RecordsLocation.email,      imageName: "Email"),
        .init(label: L10n.Onboarding.RecordsLocation.whatsapp,   imageName: "whatsapp"),
        .init(label: L10n.Onboarding.RecordsLocation.folder,     imageName: "folder"),
        .init(label: L10n.Onboarding.RecordsLocation.shelf,      imageName: "shelf"),
        .init(label: L10n.Onboarding.RecordsLocation.everywhere, imageName: "everywhere"),
    ]

    // MARK: - State

    @State private var selected: Set<Int> = []
    @State private var showTitle: Bool = false
    @State private var visibleRowCount: Int = 0
    @State private var showButton: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleSection
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 28)

            optionsList
                .padding(.horizontal, 16)

            Spacer()

            continueButton
        }
        .task { await runAnimationSequence() }
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(L10n.Onboarding.RecordsLocation.title)
            .font(.displayL)
            .fontWeight(.bold)
            .foregroundStyle(Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(showTitle ? 1 : 0)
            .offset(y: showTitle ? 0 : 20)
            .animation(
                reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                value: showTitle
            )
    }

    // MARK: - Options list

    private var optionsList: some View {
        VStack(spacing: 10) {
            ForEach(options.indices, id: \.self) { index in
                optionRow(index: index)
                    .opacity(index < visibleRowCount ? 1 : 0)
                    .offset(y: index < visibleRowCount ? 0 : 30)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.82),
                        value: visibleRowCount
                    )
            }
        }
    }

    private func optionRow(index: Int) -> some View {
        let isSelected = selected.contains(index)

        return Button {
            if isSelected { selected.remove(index) } else { selected.insert(index) }
        } label: {
            HStack(spacing: 14) {
                // Icon
                Image(options[index].imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)

                // Label
                Text(options[index].label)
                    .font(.bodyL)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                // Checkbox
                checkboxView(isSelected: isSelected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func checkboxView(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.textPrimary : Color.clear)
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.clear : Color.stroke, lineWidth: 1.5)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Continue button

    private var continueButton: some View {
        OnboardingContinueButton(action: viewModel.advance, isEnabled: !selected.isEmpty)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 30)
            .animation(
                reduceMotion ? .none : .spring(response: 0.55, dampingFraction: 0.82),
                value: showButton
            )
    }

    // MARK: - Animation sequence

    @MainActor
    private func runAnimationSequence() async {
        guard !reduceMotion else {
            showTitle = true
            visibleRowCount = options.count
            showButton = true
            return
        }

        // Title
        try? await Task.sleep(for: .milliseconds(100))
        showTitle = true

        // Rows stagger in
        try? await Task.sleep(for: .milliseconds(250))
        for i in 0..<options.count {
            if i > 0 { try? await Task.sleep(for: .milliseconds(100)) }
            visibleRowCount = i + 1
        }

        // Button
        try? await Task.sleep(for: .milliseconds(200))
        showButton = true
    }
}

#Preview {
    OnboardingRecordsLocationStep(viewModel: OnboardingViewModel())
        .background(Color.backgroundPrimary)
}
