import SwiftUI

// MARK: - Main Container

struct MainTabGlassView: View {
    
    @State private var selectedTab: MainTab = .home
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
//                    GlassTabSelector(selectedTab: $selectedTab)
                    
                    Spacer()
                    
                    FloatingActionButtonsTwo()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
        }
    }
}

// MARK: - Tab Enum

enum MainTab {
    case home
    case docs
}

// MARK: - Glass Tab Selector

struct GlassTabSelector: View {
    
    @Binding var selectedTab: MainTab
    
    var body: some View {
        HStack(spacing: 8) {
            tabItem(title: "Home", icon: "house", tab: .home)
            tabItem(title: "Docs", icon: "doc.text", tab: .docs)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }
    
    private func tabItem(title: String,
                         icon: String,
                         tab: MainTab) -> some View {
        
        let isSelected = selectedTab == tab
        
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .orange : .primary)
            .frame(width: 80, height: 70)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Buttons

struct FloatingActionButtonsTwo: View {
    
    var body: some View {
        HStack(spacing: 16) {
            
            Button {
                
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 75, height: 80)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
            }
            
            Button {
                
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 75, height: 80)
                    .background(Color.orange)
                    .clipShape(Circle())
//                    .shadow(color: .orange.opacity(0.5), radius: 20, y: 10)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabGlassView()
}
