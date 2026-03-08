import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShareHealthProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
            // TODO: Share action
        } label: {
            HStack(spacing: 10) {
                Text("Share")
                    .font(.headingS)
                    .foregroundColor(.white)

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.surfaceDark)
            .clipShape(Capsule())
        }
    }

    // MARK: - QR Generator

    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return UIImage(systemName: "qrcode") ?? UIImage()
        }

        return UIImage(cgImage: cgImage)
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
