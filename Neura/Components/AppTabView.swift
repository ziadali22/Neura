//
//  AppTabView.swift
//  Neura
//
//  Created by ziad on 23/02/2026.
//

import SwiftUI

// MARK: - Main AppTabView
struct AppTabView: View {
    @Binding var activeTab: AppTab
    @Binding var isExpanded: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Glass Effect Tab Bar
            VStack(spacing: 0) {
                // Subtle divider
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5)

                HStack(alignment: .center, spacing: 0) {
                    // Tab items using MorphingTabBar
                    HStack(spacing: 40) {
                        TabBarButton(
                            icon: "house",
                            title: "Home",
                            isSelected: activeTab == .home,
                            action: { activeTab = .home }
                        )

                        TabBarButton(
                            icon: "doc",
                            title: "Docs",
                            isSelected: activeTab == .docs,
                            action: { activeTab = .docs }
                        )
                    }
                    .padding(.leading, 32)

                    Spacer()

                    // Floating buttons
                    HStack(spacing: 16) {
                        FloatingButton(
                            icon: "plus",
                            backgroundColor: .white,
                            foregroundColor: .black,
                            size: 56,
                            hasShadow: true,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isExpanded.toggle()
                                }
                            }
                        )

                        FloatingButton(
                            icon: "square.and.arrow.up",
                            backgroundColor: .orange,
                            foregroundColor: .white,
                            size: 64,
                            hasShadow: true,
                            shadowColor: Color.orange.opacity(0.4),
                            action: { activeTab = .upload }
                        )
                    }
                    .padding(.trailing, 24)
                }
                .frame(height: 84)
            }
            .frame(height: 84)
            .background(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
        }
    }
}

fileprivate struct CustomTabBar: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    
    
    var tint: Color = .gray.opacity(0.15)
    var symbols: [String]
    
    @Binding var index: Int
    var image: (String) -> UIImage?

    func makeUIView(context: Context) -> some UISegmentedControl {
        let control = UISegmentedControl(items: symbols)
        control.selectedSegmentIndex = index
        control.selectedSegmentTintColor = UIColor(tint)
        
        for (index, symbol) in symbols.enumerated() {
            control.setImage(image(symbol), forSegmentAt: index)
        }
        
        control.addTarget(context.coordinator, action: #selector(context.coordinator.didSelect(_:)), for: .valueChanged)
        
        DispatchQueue.main.async {
            for view in control.subviews.dropLast() {
                if view is UIImageView {
                    view.alpha = 0
                }
            }
        }
        return control
    }
    
    func updateUIView(_ uiview: UIViewType, context: Context) {
        if uiview.selectedSegmentIndex != index {
            uiview.selectedSegmentIndex = index
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIViewType, context: Context) -> CGSize? {
        return proposal.replacingUnspecifiedDimensions()
    }
    
    class Coordinator: NSObject {
        var parent: CustomTabBar
        init(parent: CustomTabBar) {
            self.parent = parent
        }
        
        @objc func didSelect(_ control: UISegmentedControl) {
            parent.index = control.selectedSegmentIndex
        }
    }

}

struct TestTabBar: View {
    
    @State private var activateTab: AppTab = .home
    @State private var isExpanded: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .foregroundStyle(.clear)
            
            MorphingTabBar(activeTab: $activateTab, isExpanded: $isExpanded, expandedContent: {})
            
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .orange : .gray)

                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .orange : .gray)
                }
            }
            .frame(minWidth: 50)
            .contentShape(Rectangle())
        }
    }
}

struct FloatingButton: View {
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    let size: CGFloat
    let hasShadow: Bool
    var shadowColor: Color = .black.opacity(0.1)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .shadow(
                            color: hasShadow ? shadowColor : .clear,
                            radius: 10,
                            x: 0,
                            y: 5
                        )
                )
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()
            TestTabBar()
        }
    }
}


enum AppTab: String, MorphingTabProtcol {
    case home = "Home"
    case docs = "Docs"
    case upload = "upload"
    
    var symbolImage: String {
        switch self {
        case .home:
            return "house"
        case .docs:
            return "doc"
        case .upload:
            return "arrow.2.circlepath.circle"
        }
    }

}


protocol MorphingTabProtcol: CaseIterable, Hashable {
    var symbolImage: String {get}
}

struct MorphingTabBar<Tab: MorphingTabProtcol, ExpandedContent: View>: View {
    @Binding var activeTab: Tab
    @Binding var isExpanded: Bool
    @ViewBuilder var expandedContent: ExpandedContent
    @State private var viewWidth: CGFloat?
    
    var body: some View {
        ZStack {
            let symbols = Array(Tab.allCases).compactMap({$0.symbolImage})
            let selectedIndex = Binding {
                return symbols.firstIndex(of: activeTab.symbolImage) ?? 0
            } set: { index in
                activeTab = Array(Tab.allCases)[index]
            }
            
            if let viewWidth {
                let progress: CGFloat = isExpanded ? 1 : 0
                let labelSize: CGSize = CGSize(width: viewWidth, height: 52)
                let cornerRadius: CGFloat = labelSize.height / 2
                
                ExpandableGlassMenu(alignment: .center, progress: progress, cornerRadius: cornerRadius) {
                    
                } label: {
                    CustomTabBar(symbols: symbols, index: selectedIndex) { image in
                        let font = UIFont.systemFont(ofSize: 19)
                        let configurations = UIImage.SymbolConfiguration(font: font)
                        return UIImage(systemName: image, withConfiguration: configurations)
                    }
                }
            }
        }
        
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: { newValue in
            viewWidth = newValue
        }
        .frame(height: viewWidth == nil ? 52 : nil)
    }
}


