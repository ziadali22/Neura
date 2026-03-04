//
//  ProfileView.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//

import SwiftUI

struct ProfileView: View {
    @State private var titleAppear = false
    @State private var proCardAppear = false
    @State private var optionsAppear = false
    @State private var medicalCardsAppear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text("Profile")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(hex: "#1f1f1f"))
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .opacity(titleAppear ? 1 : 0)
                    .offset(y: titleAppear ? 0 : -20)

                VStack(alignment: .leading, spacing: 24) {
                    // Get Neura Pro Card
                    NeuraProCard()
                        .scaleEffect(proCardAppear ? 1 : 0.95)
                        .opacity(proCardAppear ? 1 : 0)

                    // Settings Options
                    VStack(spacing: 11) {
                        SettingsRow(icon: "creditcard", title: "Language")
                        SettingsRow(icon: "gearshape", title: "Settings")
                        SettingsRow(icon: "creditcard", title: "Subscription")
                        SettingsRow(icon: "creditcard", title: "Security")
                        SettingsRow(icon: "star", title: "Feedback")
                    }
                    .opacity(optionsAppear ? 1 : 0)
                    .offset(y: optionsAppear ? 0 : 20)
                }
                .padding(.horizontal, 20)

                // Medical Information Cards
//                VStack(spacing: 12) {
//                    MedicalInfoCard(
//                        icon: "💊",
//                        title: "Ongoing Medications",
//                        items: ["Ibuprofen (as needed)", "Vitamin D"]
//                    )
//
//                    MedicalInfoCard(
//                        icon: "🏥",
//                        title: "Known Conditions",
//                        content: "None diagnosed"
//                    )
//
//                    MedicalInfoCard(
//                        icon: "🏥",
//                        title: "Recent Test Highlights",
//                        items: [
//                            "Blood Panel - Mild inflammation markers",
//                            "MRI - No structural abnormalities"
//                        ]
//                    )
//
//                    AddCategoryButton()
//                }
//                .padding(.horizontal, 20)
//                .opacity(medicalCardsAppear ? 1 : 0)
//                .offset(y: medicalCardsAppear ? 0 : 30)

                Spacer()
                    .frame(height: 100)
            }
        }
        .background(Color(hex: "#fcfaf8"))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                titleAppear = true
            }

            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                proCardAppear = true
            }

            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                optionsAppear = true
            }

            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3)) {
                medicalCardsAppear = true
            }
        }
    }
}

// MARK: - Neura Pro Card
struct NeuraProCard: View {
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Get Neura Pro")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: true, vertical: false)

                Text("Unlimited Documents Uploads")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#e7e0d8"))
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer()
            
            Image("premiumIcon")
                .resizable()
                .frame(width: 60, height: 60)

            // Stacked Folders Icon
//            ZStack {
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(
//                        LinearGradient(
//                            colors: [Color.orange, Color.yellow],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//                    .frame(width: 40, height: 45)
//                    .offset(x: 8)
//
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(
//                        LinearGradient(
//                            colors: [Color.orange, Color.yellow],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//                    .frame(width: 50, height: 45)
//                    .offset(x: 2, y: 8)
//
//                RoundedRectangle(cornerRadius: 12)
//                    .fill(
//                        LinearGradient(
//                            colors: [Color.cyan, Color.green, Color.yellow],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//                    .frame(width: 58, height: 45)
//                    .overlay(
//                        Image(systemName: "plus")
//                            .font(.system(size: 20, weight: .bold))
//                            .foregroundColor(Color(hex: "#1f1f1f"))
//                    )
//                    .offset(y: 16)
//            }
//            .frame(width: 70, height: 70)
        }
        .padding(20)
        .frame(height: 102)
        .background(Color(hex: "#1f1f1f"))
        .cornerRadius(20)
        .shadow(color: Color.gray.opacity(0.25), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#1f1f1f"))
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#1f1f1f"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#7a7a7a"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(height: 62)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.gray.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Medical Info Card
struct MedicalInfoCard: View {
    let icon: String
    let title: String
    var items: [String]?
    var content: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 18))

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#ff5a00"))
            }

            if let items = items {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "#1f1f1f"))

                            Text(item)
                                .font(.system(size: 17))
                                .foregroundColor(Color(hex: "#1f1f1f"))
                        }
                    }
                }
            } else if let content = content {
                Text(content)
                    .font(.system(size: 17))
                    .foregroundColor(Color(hex: "#1f1f1f"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }
}

// MARK: - Add Category Button
struct AddCategoryButton: View {
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            HStack {
                Text("Add Category")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#1f1f1f"))

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#1f1f1f"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(height: 50)
            .background(Color.white)
            .cornerRadius(16)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    ProfileView()
}
