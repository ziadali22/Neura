//
//  CategoryFilterView.swift
//  Neura
//
//  Created by ziad on 24/02/2026.
//

import SwiftUI

struct CategoryFilterView: View {
    @Binding var selectedCategory: Category

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Category.allCases) { category in
                    CategoryFilterButton(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : Color(red: 0.3, green: 0.3, blue: 0.3))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(red: 0.94, green: 0.94, blue: 0.94))
                )
        }
    }
}

#Preview {
    CategoryFilterView(selectedCategory: .constant(.all))
        .background(Color(red: 0.99, green: 0.98, blue: 0.97))
}
