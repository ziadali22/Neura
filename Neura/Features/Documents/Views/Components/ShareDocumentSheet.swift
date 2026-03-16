import SwiftUI

struct ShareDocumentSheet: View {
    @ObservedObject var viewModel: ShareDocumentViewModel
    @Environment(\.dismiss) private var dismiss

    let documentName: String

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.textTertiary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            ZStack {
                switch viewModel.state {
                case .idle:
                    Color.clear.onAppear {
                        viewModel.startSharing()
                    }
                case .uploading:
                    uploadingView
                case .ready:
                    readyView
                case .expired:
                    expiredView
                case .error(let message):
                    errorView(message: message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.backgroundModal)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Subviews

private extension ShareDocumentSheet {

    // MARK: Uploading

    var uploadingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .controlSize(.large)
                    .tint(.accent)
            }

            VStack(spacing: 6) {
                Text("Uploading Document")
                    .font(.headingS)
                    .foregroundColor(.textPrimary)

                Text(documentName)
                    .font(.bodyS)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: Ready

    var readyView: some View {
        VStack(spacing: 20) {
            Spacer()

            // QR Code card
            if let qrImage = viewModel.qrImage {
                VStack(spacing: 16) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)

                    Text(documentName)
                        .font(.headingXS)
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                }
                .padding(24)
                .background(Color.surfaceWhite)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            }

            // Countdown timer
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                Text(viewModel.remainingTime)
                    .font(.bodyS)
                    .fontWeight(.medium)
            }
            .foregroundColor(viewModel.isUrgent ? .accent : .textSecondary)

            Text("Scan this QR code to open the document")
                .font(.captionS)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)

            Spacer()

            // Copy link button
            Button {
                viewModel.copyLink()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 15))
                    Text("Copy Link")
                        .font(.buttonL)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.surfaceDark)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Expired

    var expiredView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 34))
                    .foregroundColor(.accent)
            }

            VStack(spacing: 6) {
                Text("Link Expired")
                    .font(.headingS)
                    .foregroundColor(.textPrimary)

                Text("This sharing link has expired for security.\nGenerate a new one to continue sharing.")
                    .font(.bodyS)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            Button {
                viewModel.regenerateLink()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                    Text("Generate New Link")
                        .font(.buttonL)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Error

    func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.red)
            }

            VStack(spacing: 6) {
                Text("Upload Failed")
                    .font(.headingS)
                    .foregroundColor(.textPrimary)

                Text(message)
                    .font(.bodyS)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()

            Button {
                viewModel.regenerateLink()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                    Text("Retry")
                        .font(.buttonL)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ShareDocumentSheet(
                viewModel: ShareDocumentViewModel(
                    fileData: Data(),
                    filename: "test.pdf",
                    mimeType: "application/pdf"
                ),
                documentName: "Blood Test Results"
            )
        }
}
