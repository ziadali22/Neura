import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentSlide = 0
    @State private var scrollID: Int? = 0
    @State private var selectedPlan: Plan = .yearly
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var alertMessage: String?

    // MARK: - Plan Model

    enum Plan: CaseIterable {
        case monthly, yearly

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly:  return "Yearly"
            }
        }

        /// App Store Connect product identifier this plan maps to.
        var productID: String {
            switch self {
            case .monthly: return SubscriptionManager.Product_ID.monthly
            case .yearly:  return SubscriptionManager.Product_ID.annual
            }
        }

        /// Period suffix appended to the localized price (e.g. "/month").
        var periodSuffix: String {
            switch self {
            case .monthly: return "/month"
            case .yearly:  return "/year"
            }
        }

        var isBestValue: Bool { self == .yearly }
    }

    // MARK: - Pricing helpers (live from StoreKit, with graceful fallback)

    private func product(for plan: Plan) -> Product? {
        subscriptionManager.product(for: plan.productID)
    }

    /// True while the selected plan's product is still being fetched from StoreKit —
    /// drives the CTA spinner so an unloaded button reads as "loading", not "broken".
    private var isPreparingProducts: Bool {
        product(for: selectedPlan) == nil && subscriptionManager.isLoadingProducts
    }

    private func priceText(for plan: Plan) -> String {
        guard let product = product(for: plan) else {
            return plan == .yearly ? "$49.99/year" : "$3.99/month"
        }
        return product.displayPrice + plan.periodSuffix
    }

    /// "only $4.16/month" derived from the annual price; nil for the monthly plan.
    private func perMonthText(for plan: Plan) -> String? {
        guard plan == .yearly, let product = product(for: plan) else { return nil }
        let perMonth = product.price / 12
        return "only " + perMonth.formatted(product.priceFormatStyle) + "/month"
    }

    // MARK: - Slide Model

    struct Slide {
        let image: String
        let title: String
        let subtitle: String
    }

    private let slides: [Slide] = [
        Slide(image: "mockup",  title: "All your records with you",   subtitle: "No more digging before a visit."),
        Slide(image: "scan",    title: "Upload in seconds",           subtitle: "Scan or upload anything, anytime."),
        Slide(image: "doctors", title: "Share with your doctors",     subtitle: "Never explain your history from scratch again."),
        Slide(image: "cards",   title: "Your card, your style",       subtitle: "Only you see it. Make it personal."),
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            background
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 16)
                VStack(spacing: 8) {
                    carousel
                        .frame(height: 360)
                    pageDots
                }
                .padding(.bottom, 8)

                Spacer(minLength: 16)

                VStack(spacing: 20) {
                    plansRow
                    VStack(spacing: 12) {
                        ctaButton
                        cancelLabel
                    }
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .task { await subscriptionManager.loadProducts() }
        .onAppear { AnalyticsManager.shared.track("paywall_viewed") }
        .alert(
            "Neura Pro",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "ECA882"), location: 0.0),
                .init(color: Color(hex: "F5DDD0"), location: 0.35),
                .init(color: Color(hex: "F5EDE5"), location: 0.6),
                .init(color: Color(hex: "F5EDE5"), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                Task { await restore() }
            } label: {
                Group {
                    if isRestoring {
                        ProgressView()
                            .tint(Color.textPrimary.opacity(0.7))
                    } else {
                        Text("Restore")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.textPrimary.opacity(0.7))
                    }
                }
            }
            .disabled(isRestoring || isPurchasing)

            Spacer()

            VStack(spacing: 8) {
                Image("nOrange")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                Text("Get Neura Pro")
                    .font(.system(size: 18, weight: .medium))
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Carousel

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(slides.indices, id: \.self) { i in
                    SlideView(slide: slides[i])
                        .containerRelativeFrame(.horizontal)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollID)
        .scrollClipDisabled(false)
        .onChange(of: scrollID) { _, newID in
            currentSlide = newID ?? 0
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.5))
                let next = ((scrollID ?? 0) + 1) % slides.count
                withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                    scrollID = next
                }
            }
        }
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { i in
                Capsule()
                    .fill(i == currentSlide ? Color.accent : Color.black.opacity(0.2))
                    .frame(width: i == currentSlide ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentSlide)
            }
        }
    }

    // MARK: - Plans Row

    private var plansRow: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Plan.allCases, id: \.title) { plan in
                PlanCard(
                    plan: plan,
                    priceText: priceText(for: plan),
                    perMonthText: perMonthText(for: plan),
                    isSelected: selectedPlan == plan
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedPlan = plan
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            Group {
                if isPurchasing || isPreparingProducts {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Get Neura Pro")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Color.black)
            .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isPurchasing || isRestoring || product(for: selectedPlan) == nil)
        .opacity(product(for: selectedPlan) == nil && !isPreparingProducts ? 0.6 : 1)
    }

    // MARK: - Cancel Label

    private var cancelLabel: some View {
        Text("Cancel anytime")
            .font(.system(size: 13))
            .foregroundStyle(Color.black.opacity(0.4))
    }

    // MARK: - Legal Footer

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://myneura.org/privacy")!

    private var renewalDisclosure: String {
        let price = priceText(for: selectedPlan)
        let period = selectedPlan == .yearly ? "year" : "month"
        return "Subscription is \(price). It automatically renews each \(period) unless cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple Account. Manage or cancel anytime in your App Store settings."
    }

    private var legalFooter: some View {
        VStack(spacing: 8) {
            Text(renewalDisclosure)
                .font(.system(size: 10))
                .foregroundStyle(Color.black.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(1)

            HStack(spacing: 6) {
                Link("Terms of Use", destination: Self.termsURL)
                Text("·").foregroundStyle(Color.black.opacity(0.3))
                Link("Privacy Policy", destination: Self.privacyURL)
            }
            .font(.system(size: 11, weight: .medium))
            .tint(Color.black.opacity(0.55))
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Purchase / Restore

    @MainActor
    private func purchase() async {
        guard let product = product(for: selectedPlan), !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        switch await subscriptionManager.purchase(product) {
        case .success:
            dismiss()
        case .pending:
            alertMessage = "Your purchase is pending approval. You'll get access once it's confirmed."
        case .cancelled:
            break
        case .failed:
            alertMessage = "Something went wrong with your purchase. Please try again."
        }
    }

    @MainActor
    private func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        if await subscriptionManager.restore() {
            dismiss()
        } else {
            alertMessage = "No active subscription found to restore."
        }
    }
}

// MARK: - Slide View

private struct SlideView: View {
    let slide: PaywallView.Slide

    var body: some View {
        VStack(spacing: 20) {
            Image(slide.image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 8) {
                Text(slide.title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(slide.subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: PaywallView.Plan
    let priceText: String
    let perMonthText: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button { onTap() } label: {
            ZStack(alignment: .top) {
                cardBody
                if plan.isBestValue { bestValueBadge }
            }
        }
        .buttonStyle(.plain)
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Invisible badge-height placeholder keeps both cards equal height
            Text("BEST VALUE")
                .font(.system(size: 13, weight: .bold))
                .opacity(0)
                .padding(.vertical, 4)

            Text(plan.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.textPrimary)

            Text(priceText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.textPrimary)

            // Invisible sublabel placeholder for monthly — preserves height
            Text(perMonthText ?? " ")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
                .opacity(perMonthText != nil ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(isSelected ? Color.accent.opacity(0.08) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isSelected ? Color.accent : Color.black.opacity(0.1),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }

    private var bestValueBadge: some View {
        Text("BEST VALUE")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accent)
            .clipShape(Capsule())
            .offset(y: -16)
    }
}

// MARK: - Preview

#Preview {
    PaywallView(subscriptionManager: .shared)
}
