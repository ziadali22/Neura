import SwiftUI

struct EmptyDocumentsView: View {
    let onAddDocument: () -> Void
    @State private var scanPosition: CGFloat = -1.5

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            DocumentIllustration()
                .frame(width: 240, height: 240)
                .onAppear {
                    withAnimation(
                        .linear(duration: 2.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        scanPosition = 1.5
                    }
                }

            VStack(spacing: 8) {
                Text(L10n.Documents.noDocumentsMessage)
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text(L10n.Documents.noDocumentsMessage)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Button(action: onAddDocument) {
                HStack(spacing: 8) {
                    Text(L10n.Documents.addDocument)
                        .font(.system(size: 17, weight: .semibold))

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.black)
                .cornerRadius(25)
            }
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .environment(\.scanPosition, scanPosition)
    }
}

// MARK: - Environment Key

private struct ScanPositionKey: EnvironmentKey {
    static let defaultValue: CGFloat = -1.5
}

extension EnvironmentValues {
    var scanPosition: CGFloat {
        get { self[ScanPositionKey.self] }
        set { self[ScanPositionKey.self] = newValue }
    }
}

// MARK: - Document Illustration

private struct DocumentIllustration: View {
    @Environment(\.scanPosition) private var scanPosition

    var body: some View {
        ZStack {
            DocumentCard(showAccent: false)
                .frame(width: 160, height: 200)
                .rotationEffect(.degrees(-8))
                .offset(x: -35, y: 8)

            DocumentCard(showAccent: false)
                .frame(width: 160, height: 200)
                .rotationEffect(.degrees(5))
                .offset(x: 25, y: -8)
        }
    }
}

private struct DocumentCard: View {
    let showAccent: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .overlay(
                VStack(spacing: 0) {
                    if showAccent {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.3), Color.orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 6)
                            .offset(y: 65)
                    }

                    DocumentContent()
                        .padding(16)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct DocumentContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 4)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 4)
                .frame(width: 120)

            Spacer()
                .frame(height: 20)

            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 3)
            }
        }
    }
}

#Preview {
    EmptyDocumentsView(onAddDocument: {})
        .background(Color(.systemGroupedBackground))
}
