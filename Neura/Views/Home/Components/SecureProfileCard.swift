//
//  SecureProfileCard.swift
//  Neura
//
//  Created by ziad on 01/03/2026.
//

import SwiftUI

struct SecureProfileCard: View {
    let name: String
    let location: String
    let backgroundImage: String
    
    // State to track the drag gesture for the 3D effect
    @State private var dragAmount = CGSize.zero
    
    var body: some View {
        ZStack {
            Image(backgroundImage)
                .resizable()
                .scaledToFill()
                .frame(height: 450)
                .clipShape(RoundedRectangle(cornerRadius: 40))
                .overlay {
                    VStack {
                        topBar
                            .padding(.horizontal, 35)
                            .padding(.top, 24)
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Text(name)
                                .font(.system(size: 32, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                            
                            locationView
                        }
                        .padding(.bottom, 24)
                        .padding(.horizontal, 35)
                    }
                }
                // Dynamic shadow based on your original styling
                .shadow(
                    color: .black.opacity(0.15),
                    radius: 15,
                    x: -dragAmount.width / 10,
                    y: 10 - dragAmount.height / 10
                )
        }
//        .padding()
        // 1. Apply 3D Rotation on the X and Y axes based on drag amount
        .rotation3DEffect(
            .degrees(-Double(dragAmount.width) / 15),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(dragAmount.height) / 15),
            axis: (x: 1, y: 0, z: 0)
        )
        // 2. Gesture tracking to power the 3D effect
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring()) {
                        dragAmount = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        dragAmount = .zero
                    }
                }
        )
    }
}

#Preview {
    SecureProfileCard(
        name: "Ziad Ali Khalil",
        location: "Egypt, Cairo",
        backgroundImage: "BG6"
    )
}

// MARK: - Subviews
private extension SecureProfileCard {
    
    var topBar: some View {
        HStack {
            Label("ENCRYPTED & SECURE", systemImage: "checkmark.shield")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button {} label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 35, height: 35)
                    .background(.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
    }
    
    var locationView: some View {
        Label(location, systemImage: "house")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.6))
            .clipShape(Capsule())
    }
}
