//
//  DashboardView.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//

import SwiftUI

struct DashboardView: View {
    @State private var selectedTab: Int = 1 // Start with Home
    @State private var isExpanded: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(0)

                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(1)

                DocsView()
                    .tabItem {
                        Label("Docs", systemImage: "doc.text.fill")
                    }
                    .tag(2)
            }
            .tint(.orange)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)

            // Floating Action Buttons
            FloatingActionButtons(
                onAddTap: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                },
                onUploadTap: {
                    print("Upload tapped")
                }
            )
            .padding(.trailing, 24)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Floating Action Buttons
struct FloatingActionButtons: View {
    let onAddTap: () -> Void
    let onUploadTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Add Button
            Button(action: onAddTap) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(Color.orange)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
            }

            // Upload Button (Orange)
//            Button(action: onUploadTap) {
//                Image(systemName: "square.and.arrow.up")
//                    .font(.system(size: 24, weight: .semibold))
//                    .foregroundColor(.white)
//                    .frame(width: 64, height: 64)
//                    .background(
//                        Circle()
//                            .fill(
//                                LinearGradient(
//                                    colors: [Color.orange, Color.orange.opacity(0.8)],
//                                    startPoint: .topLeading,
//                                    endPoint: .bottomTrailing
//                                )
//                            )
//                            .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 5)
//                    )
//            } 
        }
    }
}

#Preview {
    DashboardView()
}
