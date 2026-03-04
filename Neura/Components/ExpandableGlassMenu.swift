//
//  ExpandableGlassMenu.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//


import SwiftUI

// MARK: - ExpandableGlassMenu

struct ExpandableGlassMenu<Content: View, Label: View>: View, Animatable {
    
    // MARK: Public Properties
    
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat
    
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    
    // MARK: Private State
    
    @State private var contentSize: CGSize = .zero
    
    // MARK: Animatable
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    // MARK: Body
    
    var body: some View {
        GlassEffectContainer {
            
            let widthDiff  = contentSize.width  - labelSize.width
            let heightDiff = contentSize.height - labelSize.height
            
            let rWidth  = widthDiff  * contentOpacity
            let rHeight = heightDiff * contentOpacity
            
            ZStack(alignment: alignment) {
                
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { newValue in
                        contentSize = newValue
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        width: labelSize.width + rWidth,
                        height: labelSize.height + rHeight
                    )
                
                label
                    .compositingGroup()
                    .blur(radius: 14 * blurProgress)
                    .opacity(1 - labelOpacity)
                    .frame(
                        width: labelSize.width,
                        height: labelSize.height
                    )
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: cornerRadius))
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
        .scaleEffect(
            x: 1 - (blurProgress * 0.5),
            y: 1 + (blurProgress * 0.35),
            anchor: scaleAnchor
        )
        .offset(y: offset * blurProgress)
    }
}

// MARK: - Animation Calculations

private extension ExpandableGlassMenu {
    
    var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }
    
    var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }
    
    var contentScale: CGFloat {
        guard contentSize != .zero else { return 1 }
        
        let minAspectScale = min(
            labelSize.width  / contentSize.width,
            labelSize.height / contentSize.height
        )
        
        return minAspectScale + (1 - minAspectScale) * progress
    }
    
    /// 0 → 0.5 → 0
    var blurProgress: CGFloat {
        progress > 0.5
        ? (1 - progress) / 0.5
        : progress / 0.5
    }
    
    var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing:
            return -80
        case .top, .topLeading, .topTrailing:
            return 80
        default:
            return 0
        }
    }
    
    var scaleAnchor: UnitPoint {
        switch alignment {
        case .top:
            return .top
        case .bottom:
            return .bottom
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .topLeading:
            return .topLeading
        case .topTrailing:
            return .topTrailing
        case .bottomLeading:
            return .bottomLeading
        case .bottomTrailing:
            return .bottomTrailing
        default:
            return .center
        }
    }
}
