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
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : Color(red: 0.12, green: 0.12, blue: 0.12))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color.white)
                )
                .shadow(color: isSelected ? Color.black.opacity(0.15) : Color.gray.opacity(0.1),
                       radius: isSelected ? 8 : 4, x: 0, y: 2)
        }
    }
}

#Preview {
    CategoryFilterView(selectedCategory: .constant(.all))
        .background(Color(red: 0.99, green: 0.98, blue: 0.97))
}
