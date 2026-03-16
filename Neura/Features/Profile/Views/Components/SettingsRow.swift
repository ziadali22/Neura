import SwiftUI

struct SettingsRow: View {
    let icon: String
    let title: String
    var style: RowStyle = .normal
    var showChevron: Bool = true
    var action: (() -> Void)? = nil

    enum RowStyle {
        case normal
        case destructive
    }

    init(icon: String, title: String, style: RowStyle = .normal, showChevron: Bool = true, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.style = style
        self.showChevron = showChevron
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(icon)
                    .font(.system(size: 20))
                    .foregroundColor(style == .destructive ? .red : .textPrimary)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.bodyL)
                    .foregroundColor(style == .destructive ? .red : .textPrimary)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.surfaceWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    VStack(spacing: 11) {
        SettingsRow(icon: "gearshape", title: "Settings")
        SettingsRow(icon: "star", title: "Feedback")
        SettingsRow(icon: "trash", title: "Delete Account", style: .destructive, showChevron: false)
    }
    .padding()
    .background(Color.backgroundPrimary)
}
