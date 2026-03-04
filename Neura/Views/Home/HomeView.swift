//
//  HomeView.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//

import SwiftUI

struct HomeView: View {
    @State private var greetingAppear = false
    @State private var profileCardAppear = false
    @State private var completeCardAppear = false
    @State private var recentAppear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Greeting with slide and fade animation
                Text("Good morning")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(hex: "#1f1f1f"))
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .opacity(greetingAppear ? 1 : 0)
                    .offset(y: greetingAppear ? 0 : -20)

                VStack(alignment: .leading, spacing: 24) {
                    // Profile Card with scale animation
                    SecureProfileCard(name: "CRISTINA\nGAFITESCU",
                                      location: "Iasi, Romania",
                                      backgroundImage: "BG6")
                        .scaleEffect(profileCardAppear ? 1 : 0.95)
                        .opacity(profileCardAppear ? 1 : 0)

                    // Complete Profile Card with slide from bottom
                    CompleteProfileCard()
                        .offset(y: completeCardAppear ? 0 : 30)
                        .opacity(completeCardAppear ? 1 : 0)
                }
                .padding(.horizontal, 20)

                // Recent Section with fade
                VStack(alignment: .leading, spacing: 24) {
                    Text("Recent")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "#1f1f1f"))
                        .padding(.horizontal, 20)

                    // Empty State
                    Text("Nothing here yet. Add or scan\na document")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#7a7a7a"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                }
                .opacity(recentAppear ? 1 : 0)
            }
        }
        .background(Color(hex: "#fcfaf8"))
        .onAppear {
            // Staggered animations
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                greetingAppear = true
            }

            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                profileCardAppear = true
            }

            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                completeCardAppear = true
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                recentAppear = true
            }
        }
    }
}

// MARK: - Profile Card
struct ProfileCard: View {
    @State private var badgeAppear = false
    @State private var nameAppear = false
    @State private var buttonScale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(hex: "#1a5a5a"),
                    Color(hex: "#4a8a7a"),
                    Color(hex: "#8abaa0")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 420)
            .cornerRadius(42)
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)

            // Bottom Gradient Overlay
            VStack {
                Spacer()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 182)
                .overlay(
                    VStack(spacing: 16) {
                        Text("CRISTINA\nGAFITESCU")
                            .font(.system(size: 42, weight: .heavy))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .condensed()
                            .opacity(nameAppear ? 1 : 0)
                            .scaleEffect(nameAppear ? 1 : 0.9)

                        HStack(spacing: 10) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)

                            Text("Iasi, Romania")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#1f1f1f"))
                        .cornerRadius(99)
                        .opacity(nameAppear ? 1 : 0)
                        .offset(y: nameAppear ? 0 : 10)
                    }
                    .padding(.bottom, 20)
                )
            }
            .cornerRadius(42)

            // Top Badges
            HStack {
                // Encrypted Badge with pulse
                HStack(spacing: 9) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)

                    Text("ENCRYPTED & SECURE")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .opacity(badgeAppear ? 1 : 0)
                .scaleEffect(badgeAppear ? 1 : 0.8)

                Spacer()

                // Share Button with bounce
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        buttonScale = 0.9
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            buttonScale = 1.0
                        }
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#1f1f1f"))
                        .clipShape(Circle())
                }
                .scaleEffect(buttonScale)
                .opacity(badgeAppear ? 1 : 0)
            }
            .padding(18)
        }
        .frame(height: 420)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3)) {
                badgeAppear = true
            }

            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.4)) {
                nameAppear = true
            }
        }
    }
}

// MARK: - Complete Profile Card
struct CompleteProfileCard: View {
    @State private var lineAnimation = false
    @State private var arrowBounce = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Gradient Line with width animation
                LinearGradient(
                    colors: [Color.orange, Color.white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: lineAnimation ? 186 : 0, height: 1)
                .offset(x: 73, y: 1)

                // Card Content
                HStack(spacing: 13) {
                    // Icon with rotation
                    Image("profile")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(lineAnimation ? 0 : -10))

                    // Text Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Complete your profile")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#1f1f1f"))

                        Text("Add one more element to complete your medical profile.")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#4a4a4a"))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Arrow Button with bounce
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            arrowBounce.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#1f1f1f"))
                            .clipShape(Circle())
                    }
                    .scaleEffect(arrowBounce ? 0.9 : 1.0)
                    .offset(x: arrowBounce ? 5 : 0)
                }
                .padding(16)
                .frame(height: 90)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.gray.opacity(0.25), radius: 12, x: 0, y: 4)

                // Bottom Gradient Line with width animation
                LinearGradient(
                    colors: [Color.orange, Color.white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: lineAnimation ? 186 : 0, height: 1)
                .offset(x: 133, y: -1)
                .scaleEffect(x: 1, y: -1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
                lineAnimation = true
            }
        }
    }
}


#Preview {
    HomeView()
}
