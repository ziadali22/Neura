import SwiftUI

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: DocumentCategory?
    @Binding var selectedSpecialization: MedicalSpecialization?
    @Binding var sortOption: DocumentSortOption
    let resultCount: Int
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            FilterSheetHeader(onDismiss: dismiss.callAsFunction)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    FilterOrderSection(sortOption: $sortOption)
                    FilterCategorySection(selectedCategory: $selectedCategory)
                    FilterSpecializationSection(selectedSpecialization: $selectedSpecialization)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)

            FilterSheetBottomBar(
                resultCount: resultCount,
                onClear: clearFilters,
                onApply: dismiss.callAsFunction
            )
        }
        .background(Color.surfaceWhite)
    }

    private func clearFilters() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            onClear()
        }
    }
}

// MARK: - Header

private struct FilterSheetHeader: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Filters")
                .font(.headingL)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            Button("Close", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.textSecondary)
                .frame(width: 30, height: 30)
                .background(Color.backgroundCard)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.stroke, lineWidth: 1)
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }
}

// MARK: - Order Section

private struct FilterOrderSection: View {
    @Binding var sortOption: DocumentSortOption

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilterSectionTitle("Order")

            HStack(spacing: 8) {
                ForEach(DocumentSortOption.allCases) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sortOption = option
                        }
                    } label: {
                        FilterSortChip(label: option.chipLabel, isSelected: sortOption == option)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Sort Chip

private struct FilterSortChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.labelM)
            .foregroundStyle(isSelected ? .white : Color.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(minHeight: 46)
            .background(isSelected ? Color.surfaceDark : Color.clear)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule().strokeBorder(Color.stroke, lineWidth: 1.5)
                }
            }
    }
}

// MARK: - Category Section

private struct FilterCategorySection: View {
    @Binding var selectedCategory: DocumentCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilterSectionTitle("Category")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(DocumentCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    } label: {
                        FilterCategoryChip(
                            category: cat,
                            isSelected: selectedCategory == cat
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Category Chip

private struct FilterCategoryChip: View {
    let category: DocumentCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            categoryIcon
                .frame(width: 28, height: 28)
                .background(
                    isSelected
                        ? Color.white.opacity(0.18)
                        : category.color.opacity(0.12)
                )
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text(category.localizedName)
                .font(.labelM)
                .foregroundStyle(isSelected ? .white : Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(isSelected ? Color.surfaceDark : Color.clear)
        .clipShape(Capsule())
        .overlay {
            if !isSelected {
                Capsule().strokeBorder(Color.stroke, lineWidth: 1.5)
            }
        }
        .accessibilityLabel(
            Text("\(category.localizedName)\(isSelected ? ", selected" : "")")
        )
    }

    @ViewBuilder
    private var categoryIcon: some View {
        if let assetName = category.assetIcon {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .padding(4)
        } else {
            Image(systemName: category.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : category.color)
        }
    }
}

// MARK: - Specialization Section

private struct FilterSpecializationSection: View {
    @Binding var selectedSpecialization: MedicalSpecialization?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilterSectionTitle("Specialization")

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(MedicalSpecialization.allCases) { spec in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSpecialization = selectedSpecialization == spec ? nil : spec
                        }
                    } label: {
                        FilterSpecializationChip(
                            specialization: spec,
                            isSelected: selectedSpecialization == spec
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Specialization Chip

private struct FilterSpecializationChip: View {
    let specialization: MedicalSpecialization
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: specialization.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    isSelected
                        ? Color.white.opacity(0.18)
                        : Color.backgroundCard
                )
                .clipShape(Circle())
                .accessibilityHidden(true)

            Text(specialization.rawValue)
                .font(.labelM)
                .foregroundStyle(isSelected ? .white : Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(isSelected ? Color.surfaceDark : Color.clear)
        .clipShape(Capsule())
        .overlay {
            if !isSelected {
                Capsule().strokeBorder(Color.stroke, lineWidth: 1.5)
            }
        }
        .accessibilityLabel(
            Text("\(specialization.rawValue)\(isSelected ? ", selected" : "")")
        )
    }
}

// MARK: - Section Title

private struct FilterSectionTitle: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headingS)
            .foregroundStyle(Color.textPrimary)
    }
}

// MARK: - Bottom Bar

private struct FilterSheetBottomBar: View {
    let resultCount: Int
    let onClear: () -> Void
    let onApply: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button("Clear all", action: onClear)
                .font(.labelM)
                .foregroundStyle(Color.textSecondary)
                .frame(minHeight: 50)

            Spacer()

            Button(action: onApply) {
                Text("See ^[\(resultCount) result](inflect: true)")
                    .font(.buttonM)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 15)
                    .background(Color.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Divider() }
        .background(Color.surfaceWhite)
    }
}

// MARK: - Sort chip label

private extension DocumentSortOption {
    var chipLabel: String {
        switch self {
        case .newest: "Newest"
        case .oldest: "Oldest"
        case .name:   "Name A–Z"
        }
    }
}

// MARK: - Preview

#Preview {
    Color.black.opacity(0.3)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            FilterSheet(
                selectedCategory: .constant(.bloodTests),
                selectedSpecialization: .constant(nil),
                sortOption: .constant(.newest),
                resultCount: 12,
                onClear: {}
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
}
