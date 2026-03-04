//
//  EmptyDocumentsView.swift
//  Neura
//
//  Created by ziad on 23/02/2026.
//

import SwiftUI

struct EmptyDocumentsView: View {
    let onAddDocument: () -> Void
    @State private var scanPosition: CGFloat = -1.5

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Document Illustration with Scanning Light
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

            // Text
            VStack(spacing: 8) {
                Text("You have 0 medical documents.")
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("Add from your library, or scan\nthe document.")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            // Add Document Button
            Button(action: onAddDocument) {
                HStack(spacing: 8) {
                    Text("Add document")
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

// Environment key for scan position
private struct ScanPositionKey: EnvironmentKey {
    static let defaultValue: CGFloat = -1.5
}

extension EnvironmentValues {
    var scanPosition: CGFloat {
        get { self[ScanPositionKey.self] }
        set { self[ScanPositionKey.self] = newValue }
    }
}

struct DocumentIllustration: View {
    @Environment(\.scanPosition) private var scanPosition

    var body: some View {
        ZStack {
            // Back document (left)
            DocumentCard(showAccent: false)
                .frame(width: 160, height: 200)
                .rotationEffect(.degrees(-8))
                .offset(x: -35, y: 8)

            // Front document (right) with orange accent
            DocumentCard(showAccent: false)
                .frame(width: 160, height: 200)
                .rotationEffect(.degrees(5))
                .offset(x: 25, y: -8)

            // Scanning Light Effect - Wider than documents
//            Rectangle()
//                .fill(
//                    LinearGradient(
//                        colors: [
//                            Color.orange.opacity(0),
//                            Color.orange.opacity(0.15),
//                            Color.orange.opacity(0.3),
//                            Color.orange.opacity(0.15),
//                            Color.orange.opacity(0)
//                        ],
//                        startPoint: .top,
//                        endPoint: .bottom
//                    )
//                )
//                .frame(width: 360, height: 20)
//                .blur(radius: 8)
//                .offset(y: scanPosition * 120)
//                .mask(
//                    Rectangle()
//                        .frame(width: 280, height: 240)
//                )
        }
    }
}

struct DocumentCard: View {
    let showAccent: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .overlay(
                VStack(spacing: 0) {
                    if showAccent {
                        // Orange accent bar
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

struct DocumentContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Simulated document lines
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 4)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 4)
                .frame(width: 120)

            Spacer()
                .frame(height: 20)

            ForEach(0..<8) { _ in
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
