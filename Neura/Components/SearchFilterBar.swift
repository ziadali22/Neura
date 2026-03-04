//
//  SearchFilterBar.swift
//  Neura
//
//  Created by ziad on 23/02/2026.
//

import SwiftUI

struct SearchFilterBar: View {
    @Binding var searchText: String
    let onFilterTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 18))

                TextField("Search", text: $searchText)
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // Filter Button
            Button(action: onFilterTapped) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 48, height: 48)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
        }
    }
}

#Preview {
    SearchFilterBar(searchText: .constant(""), onFilterTapped: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
