import SwiftUI

struct SearchFilterBar: View {
    @Binding var searchText: String
    let onFilterTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(red: 0.27, green: 0.53, blue: 0.71))
                    .font(.system(size: 16, weight: .medium))

                TextField("Search", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.27, green: 0.53, blue: 0.71), lineWidth: 1.5)
            )

            Button(action: onFilterTapped) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                    .frame(width: 44, height: 44)
            }
        }
    }
}

#Preview {
    SearchFilterBar(searchText: .constant(""), onFilterTapped: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
