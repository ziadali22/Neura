import SwiftUI

extension View {
    func condensed() -> some View {
        self.font(.system(.largeTitle, design: .default).weight(.heavy).width(.condensed))
    }
}
