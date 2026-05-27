import SwiftUI

struct PaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var appear = false
    @State private var selectedPlan: Plan = .yearly

    enum Plan: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"

        var price: String {
            switch self {
            case .monthly: return "$4.99"
            case .yearly: return "$29.99"
            }
        }

        var period: String {
            switch self {
            case .monthly: return "/month"
            case .yearly: return "/year"
            }
        }

        var savings: String? {
            switch self {
            case .yearly: return "Save 50%"
            case .monthly: return nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.textTertiary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection
                    featuresSection
                    plansSection
                    ctaButton
                    restoreButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color.backgroundPrimary)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appear = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accent)
            }

            Text(L10n.Paywall.title)
                .font(.displayL)
                .foregroundColor(.textPrimary)

            Text(L10n.Paywall.subtitle)
                .font(.bodyL)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: 16) {
            FeatureRow(icon: "doc.fill.badge.plus", text: "Unlimited document uploads")
            FeatureRow(icon: "square.and.arrow.up.fill", text: "Share with doctors anytime")
            FeatureRow(icon: "lock.shield.fill", text: "End-to-end encryption")
            FeatureRow(icon: "sparkles", text: "Priority support")
        }
        .padding(20)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Plans

    private var plansSection: some View {
        HStack(spacing: 12) {
            ForEach(Plan.allCases, id: \.self) { plan in
                PlanCard(
                    plan: plan,
                    isSelected: selectedPlan == plan,
                    onTap: { selectedPlan = plan }
                )
            }
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button {
            subscriptionManager.upgradeToPro()
            dismiss()
        } label: {
            Text(L10n.Paywall.continueWith(selectedPlan.rawValue))
                .font(.buttonL)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            subscriptionManager.restorePurchase()
            dismiss()
        } label: {
            Text(L10n.Paywall.restore)
                .font(.bodyS)
                .foregroundColor(.textTertiary)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accent)
                .frame(width: 24)

            Text(text)
                .font(.bodyL)
                .foregroundColor(.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: PaywallView.Plan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                if let savings = plan.savings {
                    Text(savings)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accent)
                        .clipShape(Capsule())
                } else {
                    Spacer().frame(height: 20)
                }

                Text(plan.rawValue)
                    .font(.headingXS)
                    .foregroundColor(.textPrimary)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(plan.price)
                        .font(.headingL)
                        .foregroundColor(.textPrimary)

                    Text(plan.period)
                        .font(.captionS)
                        .foregroundColor(.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.surfaceWhite)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accent : Color.stroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView(subscriptionManager: .shared)
}
