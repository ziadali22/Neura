import SwiftUI

// MARK: - OnboardingCalculatingStep

struct OnboardingCalculatingStep: View {
    let viewModel: OnboardingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var titleVisible = false
    @State private var revealedCount = 0
    @State private var isComplete = false

    // Pre-computed once — viewModel.state doesn't change on this screen
    private let items: [SummaryItem]

    init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
        self.items = Self.buildItems(from: viewModel)
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
//            glowLayer

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 72)

                headerSection
                    .padding(.horizontal, 28)

                Spacer().frame(height: 44)

                itemList
                    .padding(.horizontal, 28)

                Spacer()

                progressSection
                    .padding(.horizontal, 28)
                    .padding(.bottom, 56)
            }
        }
        .task { await runSequence() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isComplete ? completionTitle : "Building your\nNeura profile…")
                .font(.displayL)
                .foregroundStyle(Color.textPrimary)
                .contentTransition(.opacity)
                .animation(
                    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.82),
                    value: isComplete
                )

            Text(isComplete ? "Welcome to a healthier you." : "Personalising your experience…")
                .font(.bodyS)
                .foregroundStyle(Color.textTertiary)
                .contentTransition(.opacity)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.3).delay(0.06),
                    value: isComplete
                )
        }
        .opacity(titleVisible ? 1 : 0)
        .offset(y: titleVisible ? 0 : 18)
        .animation(
            reduceMotion ? .none : .spring(response: 0.52, dampingFraction: 0.82),
            value: titleVisible
        )
    }

    private var completionTitle: String {
        let first = viewModel.state.name
            .components(separatedBy: " ")
            .first ?? ""
        return first.isEmpty ? "You're all set!" : "You're all set, \(first)!"
    }

    // MARK: - Item list

    private var itemList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                SummaryRow(
                    icon: item.icon,
                    label: item.label,
                    isRevealed: index < revealedCount,
                    reduceMotion: reduceMotion
                )
                .padding(.vertical, 11)
            }
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        let fraction = items.isEmpty ? 1.0 : Double(revealedCount) / Double(items.count)
        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.stroke)
                    Capsule()
                        .fill(Color.accent)
                        .frame(width: geo.size.width * fraction)
                        .animation(
                            reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.82),
                            value: revealedCount
                        )
                }
            }
            .frame(height: 3)

            Text("\(revealedCount) of \(items.count) configured")
                .font(.captionS)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Glow blobs

    private var glowLayer: some View {
        ZStack {
            Circle()
                .fill(Color.accent.opacity(0.06))
                .frame(width: 320)
                .blur(radius: 90)
                .offset(x: -80, y: -280)

            Circle()
                .fill(Color.accent.opacity(0.04))
                .frame(width: 260)
                .blur(radius: 70)
                .offset(x: 110, y: 260)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: - Sequence

    private func runSequence() async {
        try? await Task.sleep(for: .milliseconds(280))
        withAnimation { titleVisible = true }

        if reduceMotion {
            revealedCount = items.count
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation { isComplete = true }
            try? await Task.sleep(for: .milliseconds(900))
            viewModel.advance()
            return
        }

        try? await Task.sleep(for: .milliseconds(520))
        for i in 1...max(1, items.count) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                revealedCount = i
            }
            if i < items.count {
                try? await Task.sleep(for: .milliseconds(410))
            }
        }

        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            isComplete = true
        }

        try? await Task.sleep(for: .milliseconds(1500))
        viewModel.advance()
    }

    // MARK: - Item builder

    private static func buildItems(from viewModel: OnboardingViewModel) -> [SummaryItem] {
        var result: [SummaryItem] = []

        let firstName = viewModel.state.name
            .components(separatedBy: " ")
            .first ?? viewModel.state.name
        if !firstName.isEmpty {
            result.append(.init(icon: "person.fill", label: "Profile created for \(firstName)"))
        }

        let areaCount = viewModel.state.medicalAreas.count
        if areaCount > 0 {
            let label = areaCount == 1
                ? "1 medical area tracked"
                : "\(areaCount) medical areas tracked"
            result.append(.init(icon: "stethoscope", label: label))
        }

        let hasContact = !viewModel.state.emergencyContactName.isEmpty
            || !viewModel.state.emergencyContactPhone.isEmpty
        if hasContact {
            result.append(.init(icon: "staroflife.fill", label: "Emergency contact saved"))
        }

        if viewModel.healthKitStatus == .authorized {
            result.append(.init(icon: "heart.fill", label: "Apple Health connected"))
        }

        let entryCount = countEntries(viewModel.state)
        if entryCount > 0 {
            let label = entryCount == 1
                ? "1 health entry added"
                : "\(entryCount) health entries added"
            result.append(.init(icon: "cross.case.fill", label: label))
        }

        let locationParts = [viewModel.state.city, viewModel.state.country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !locationParts.isEmpty {
            result.append(.init(icon: "location.fill", label: locationParts.joined(separator: ", ")))
        }

        result.append(.init(icon: "rectangle.on.rectangle.angled", label: "Health card ready"))

        return result
    }

    private static func countEntries(_ state: OnboardingState) -> Int {
        func count(_ s: String) -> Int {
            s.split(separator: ",")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .count
        }
        return count(state.medications) + count(state.allergies) + count(state.conditions)
    }
}

// MARK: - SummaryItem

private struct SummaryItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
}

// MARK: - SummaryRow

private struct SummaryRow: View {
    let icon: String
    let label: String
    let isRevealed: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isRevealed ? Color.accent : Color.stroke)
                    .frame(width: 40, height: 40)

                Image(systemName: isRevealed ? "checkmark" : icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isRevealed ? .white : Color.textTertiary)
                    .contentTransition(.symbolEffect(.replace.offUp))
            }
            .scaleEffect(isRevealed ? 1 : 0.78)
            .animation(
                reduceMotion ? .none : .spring(response: 0.38, dampingFraction: 0.55),
                value: isRevealed
            )

            Text(label)
                .font(.bodyL)
                .foregroundStyle(isRevealed ? Color.textPrimary : Color.textTertiary)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 0.25),
                    value: isRevealed
                )
        }
        .opacity(isRevealed ? 1 : 0.4)
        .offset(x: isRevealed ? 0 : 14)
        .animation(
            reduceMotion ? .none : .spring(response: 0.48, dampingFraction: 0.75),
            value: isRevealed
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRevealed ? "\(label), configured" : "\(label), pending")
    }
}

#Preview {
    OnboardingCalculatingStep(viewModel: OnboardingViewModel())
}
