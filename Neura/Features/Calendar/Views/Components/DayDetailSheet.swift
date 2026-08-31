import SwiftUI

/// Bottom sheet showing a single day's entries (or the empty state + Add),
/// presented when a day is tapped on the calendar grid. Adding and editing
/// entries happen via nested editor sheets so the day's list updates live.
struct DayDetailSheet: View {
    let day: Date
    @ObservedObject var viewModel: CalendarViewModel
    let documents: [Document]
    var onDeleteDocument: ((Document) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var editorEntry: CalendarEntry?
    @State private var showNewEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                DayEntriesList(
                    day: day,
                    entries: viewModel.entries(on: day),
                    onTapEntry: { editorEntry = $0 },
                    onToggleComplete: { viewModel.toggleCompletion($0, on: $1) },
                    onAdd: { showNewEntry = true }
                )
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Color.backgroundPrimary)
            // Pin the add button to the bottom (only when the day already has
            // entries — the empty state shows its own centered CTA) so it never
            // scrolls out of reach on busy days.
            .safeAreaInset(edge: .bottom) {
                if !viewModel.entries(on: day).isEmpty {
                    PrimaryButton(title: L10n.Calendar.addEntry, systemImage: "plus") {
                        showNewEntry = true
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .background(
                        Color.backgroundPrimary
                            .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.headingXS)
                        .foregroundStyle(Color.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // New entry for this day
        .sheet(isPresented: $showNewEntry) {
            EntryEditorSheet(
                existing: nil,
                initialDate: day,
                documents: documents,
                onSave: { viewModel.save($0) }
            )
        }
        // Edit an existing entry
        .sheet(item: $editorEntry) { entry in
            EntryEditorSheet(
                existing: entry,
                initialDate: entry.date,
                documents: documents,
                onSave: { viewModel.save($0) },
                onDelete: { viewModel.delete($0) },
                onDeleteDocument: onDeleteDocument
            )
        }
    }
}
