import SwiftUI

struct ShareHealthProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileVM = HealthProfileViewModel()

    @State private var shareViewModel: ShareDocumentViewModel?
    @State private var isGeneratingPDF = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let shareVM = shareViewModel {
                ShareDocumentSheet(viewModel: shareVM, documentName: "Health Profile")
            } else {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 24)

                    illustrationView
                        .padding(.top, 16)

                    shareInfoSection
                        .padding(.top, 24)

                    Spacer()

                    shareButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }

                closeButton
                    .padding(.top, 14)
                    .padding(.trailing, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundModal)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textPrimary)
                .frame(width: 28, height: 28)
                .background(Color.surfaceWhite)
                .clipShape(Circle())
        }
    }

    // MARK: - Illustration

    private var illustrationView: some View {
        Image("files")
            .resizable()
            .scaledToFit()
            .frame(height: 200)
    }

    // MARK: - Share Info

    private var shareInfoSection: some View {
        VStack(spacing: 12) {
            Text("Share your Health Profile")
                .font(.headingL)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            Text("Give instant access to your essential medical summary — skip explanations, get care faster.")
                .font(.bodyL)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            generateAndShare()
        } label: {
            HStack(spacing: 10) {
                if isGeneratingPDF {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Share")
                        .font(.headingS)
                        .foregroundColor(.white)

                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.surfaceDark)
            .clipShape(Capsule())
        }
        .disabled(isGeneratingPDF)
    }

    // MARK: - Generate PDF & Share

    private func generateAndShare() {
        isGeneratingPDF = true

        Task.detached(priority: .userInitiated) {
            guard let pdfURL = await profileVM.generatePDF(),
                  let pdfData = try? Data(contentsOf: pdfURL) else {
                await MainActor.run { isGeneratingPDF = false }
                return
            }

            await MainActor.run {
                isGeneratingPDF = false
                shareViewModel = ShareDocumentViewModel(
                    fileData: pdfData,
                    filename: "Health_Profile.pdf",
                    mimeType: "application/pdf"
                )
            }
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ShareHealthProfileSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(32)
        }
}
