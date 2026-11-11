import SwiftUI
import UIKit

/// Floating pill toast matching the Figma top banner (node 2561:3481).
struct TopToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.bodyL)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.surfaceDark, in: Capsule())
            .allowsHitTesting(false)
            .accessibilityAddTraits(.isStaticText)
    }
}

struct TopToastOverlay: ViewModifier {
    @Binding var message: String?
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    TopToast(message: message)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: message)
            .sensoryFeedback(.impact(weight: .heavy), trigger: message) { _, newValue in
                newValue != nil
            }
            .onChange(of: message) { _, newValue in
                dismissTask?.cancel()
                guard let newValue else { return }
                UIAccessibility.post(notification: .announcement, argument: newValue)
                dismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.5))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        message = nil
                    }
                }
            }
    }
}

extension View {
    func topToast(_ message: Binding<String?>) -> some View {
        modifier(TopToastOverlay(message: message))
    }
}

#Preview {
    Color.backgroundPrimary
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            TopToast(message: "Profile switched successfully")
                .padding(.top, 8)
        }
}

