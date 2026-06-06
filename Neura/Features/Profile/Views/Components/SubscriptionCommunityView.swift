import SwiftUI
import StoreKit

/// Detail screen shown to Pro subscribers when they tap "Subscription" in the profile.
/// Displays the active plan, its localized price, and the next renewal (or expiry) date.
struct SubscriptionCommunityView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                Group {
                    if let subscription = subscriptionManager.activeSubscription {
                        SubscriptionCard(
                            subscription: subscription,
                            product: subscriptionManager.product(for: subscription.productID)
                        )
                    } else {
                        ProgressView()
                            .tint(Color.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .background(Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .task {
            // Ensure prices are loaded, then recompute entitlement details (plan, renewal
            // date, auto-renew flag) which are nil on a cold launch even when isPro is cached.
            await subscriptionManager.loadProducts()
            await subscriptionManager.refreshEntitlements()
        }
    }

    private var navBar: some View {
        ZStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(L10n.Profile.subscription)
                .font(.headingS)
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Subscription Card

private struct SubscriptionCard: View {
    let subscription: SubscriptionManager.ActiveSubscription
    let product: Product?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("neuraOrangeSquareLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.Profile.Subscription.planTitle(periodLabel))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.textPrimary)

                Text(L10n.Profile.Subscription.description)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                if let priceText {
                    DetailRow(icon: "calendar.badge.checkmark", text: priceText)
                }
                if let renewalText {
                    DetailRow(icon: "creditcard", text: renewalText)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private var periodLabel: String {
        subscription.isMonthly
            ? L10n.Profile.Subscription.periodMonthly
            : L10n.Profile.Subscription.periodYearly
    }

    private var priceText: String? {
        guard let product else { return nil }
        let suffix = subscription.isMonthly
            ? L10n.Profile.Subscription.perMonth
            : L10n.Profile.Subscription.perYear
        return "\(product.displayPrice) \(suffix)"
    }

    private var renewalText: String? {
        guard let date = subscription.renewalDate else { return nil }
        let dateString = date.formatted(.dateTime.day().month(.wide))
        return subscription.willAutoRenew
            ? L10n.Profile.Subscription.renewsOn(dateString)
            : L10n.Profile.Subscription.expiresOn(dateString)
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 24, alignment: .center)

            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Color.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionCommunityView()
    }
}
