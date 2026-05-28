import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            // Base background
            Color.backgroundPrimary
                .ignoresSafeArea()

            // Welcome gradient — fades in/out with the welcome step
            LinearGradient(
                colors: [
                    Color(hex: "FFBD82"),
                    Color(hex: "FF7040"),
                    Color(hex: "D6391A")
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()
            .opacity(viewModel.currentStep == .welcome ? 1 : 0)
            .animation(.easeInOut(duration: 0.35), value: viewModel.currentStep == .welcome)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .frame(height: viewModel.currentStep.showsTopBar ? 44 : 0)
                    .clipped()

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: viewModel.isComplete) { _, done in
            if done { onComplete() }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            // Centered progress pill
            if viewModel.currentStep.showsProgressBar {
                progressBar
            }

            // Back + Skip buttons — left and right aligned
            HStack {
                if viewModel.currentStep != .welcome {
                    Button("Back", systemImage: "chevron.left") {
                        HapticManager.light()
                        viewModel.goBack()
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                }
                Spacer()
                if viewModel.currentStep.isSkippable {
                    Button(L10n.Common.skip) {
                        HapticManager.light()
                        viewModel.advance()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.stroke).frame(width: 120, height: 4)
            Capsule()
                .fill(Color.accent)
                .frame(width: max(8, 120 * viewModel.progress), height: 4)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.progress)
        }
    }

    // MARK: - Step Transitions

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: viewModel.direction > 0 ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: viewModel.direction > 0 ? .leading  : .trailing).combined(with: .opacity)
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:         OnboardingWelcomeStep(viewModel: viewModel)
            case .stopSearching:   OnboardingStopSearchingStep(viewModel: viewModel)
            case .storeAndShare:   OnboardingStoreAndShareStep(viewModel: viewModel)
            case .statistics:      OnboardingStatisticsStep(viewModel: viewModel)
            case .recordsLocation: OnboardingRecordsLocationStep(viewModel: viewModel)
            case .documentScan:    OnboardingDocumentScanStep(viewModel: viewModel)
            case .privacySecurity: OnboardingPrivacyStep(viewModel: viewModel)
            case .medicalAreas:    OnboardingMedicalAreasStep(viewModel: viewModel)
            case .profile:         OnboardingProfileStep(viewModel: viewModel)
            case .location:        OnboardingLocationStep(viewModel: viewModel)
            case .profileCardIntro: OnboardingProfileCardIntroStep(viewModel: viewModel)
            case .profileCard:      OnboardingProfileCardStep(viewModel: viewModel)
            case .emergency:       OnboardingEmergencyStep(viewModel: viewModel)
            case .biometrics:      OnboardingBiometricsStep(viewModel: viewModel)
            case .emergencyCard:   OnboardingCardStep(viewModel: viewModel)
            case .healthKit:       OnboardingHealthKitStep(viewModel: viewModel)
            case .healthData:      OnboardingHealthDataStep(viewModel: viewModel)
            case .medical:         OnboardingMedicalStep(viewModel: viewModel)
            case .documents:       OnboardingDocumentsStep(viewModel: viewModel)
            case .calculating:     OnboardingCalculatingStep(viewModel: viewModel)
            }
        }
        .id(viewModel.currentStep)
        .transition(stepTransition)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.currentStep)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
