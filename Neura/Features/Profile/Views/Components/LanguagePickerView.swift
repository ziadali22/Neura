import SwiftUI

struct LanguagePickerView: View {
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            languageManager.setLanguage(language)
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Text(language.displayName)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.textPrimary)

                            Spacer()

                            if languageManager.currentLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.accent)
                            } else {
                                Circle()
                                    .stroke(Color.stroke, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(Color.surfaceWhite)
                        .cornerRadius(14)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(String(localized: "Language"))
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        LanguagePickerView()
            .environment(LanguageManager.shared)
    }
}
