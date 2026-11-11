import SwiftUI

struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        VStack(spacing: 0) {
            navBar

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            AnalyticsManager.shared.track(.languageChanged, properties: ["language": language.rawValue])
                            // Do NOT wrap this in withAnimation: changing the language
                            // re-applies \.locale / \.layoutDirection to the whole app at the
                            // NeuraApp root, which animates an app-wide re-layout. Because the
                            // tab bar lives in a bottom safeAreaInset and is hidden while this
                            // picker (a pushed detail view) is on screen, that interrupted spring
                            // leaves the bar stuck shifted up after navigating back.
                            languageManager.setLanguage(language)
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
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(Color.backgroundPrimary)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private var navBar: some View {
        ZStack {
            Button { dismiss() } label: {
                Image(systemName: LanguageManager.shared.backChevronSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.surfaceWhite)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(L10n.Profile.language)
                .font(.headingS)
                .foregroundColor(.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack {
        LanguagePickerView()
            .environment(LanguageManager.shared)
    }
}
