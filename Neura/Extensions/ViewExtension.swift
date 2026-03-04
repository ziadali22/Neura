//
//  ViewExtension.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//

import SwiftUI

extension View {
    func condensed() -> some View {
        self.font(.system(.largeTitle, design: .default).weight(.heavy).width(.condensed))
    }
}
