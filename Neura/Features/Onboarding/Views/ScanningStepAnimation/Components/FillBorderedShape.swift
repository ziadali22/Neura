//
//  FillBorderedShape.swift
//  Neura
//
//  Created by Ziad Ali Khalil on 21/03/2026.
//

import SwiftUI

struct FillBorderedShape<S: Shape>: View {
    let shape: S
    var fillColor: Color = .clear
    var borderColor: Color = .clear
    var lineWidth: CGFloat = 1

    var body: some View {
        shape
            .fill(fillColor)
            .overlay(
                shape.stroke(borderColor, lineWidth: lineWidth)
            )
    }
}
