import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var docsViewModel = DocumentsListViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var editorEntry: CalendarEntry?
    @State private var showDayDetail = false
    @State private var showNewEntry = false
    @State private var showAgenda = false
    @State private var pendingAgendaEntry: CalendarEntry?

    var body: some View {
        VStack(spacing: 0) {
            header

            // The month grid stays fixed below the header; upcoming events (when
            // any) scroll between it and the bottom-pinned "Add Event" button.
            if viewModel.upcomingItems().isEmpty {
                monthGrid
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        monthGrid

                        UpcomingEventsSection(
                            items: viewModel.upcomingItems(),
                            onTap: { editorEntry = $0 },
                            onToggleComplete: { viewModel.toggleCompletion($0, on: $1) }
                        )

                        Spacer(minLength: 20)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        // "Add Event" is always available, pinned to the bottom of the screen.
        .safeAreaInset(edge: .bottom) {
            TodayEmptyPrompt(onAdd: addEventForToday)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { docsViewModel.loadDocuments() }
        // Tap an empty day → add a new entry for it directly
        .sheet(isPresented: $showNewEntry) {
            EntryEditorSheet(
                existing: nil,
                initialDate: viewModel.selectedDay,
                documents: docsViewModel.spaceScopedDocuments,
                onSave: { viewModel.save($0) }
            )
        }
        // Day details (tap a day with entries) — lists that day's entries + add
        .sheet(isPresented: $showDayDetail) {
            DayDetailSheet(
                day: viewModel.selectedDay,
                viewModel: viewModel,
                documents: docsViewModel.spaceScopedDocuments,
                onDeleteDocument: { docsViewModel.deleteDocument($0) }
            )
        }
        // Edit existing entry (from the agenda)
        .sheet(item: $editorEntry) { entry in
            EntryEditorSheet(
                existing: entry,
                initialDate: entry.date,
                documents: docsViewModel.spaceScopedDocuments,
                onSave: { viewModel.save($0) },
                onDelete: { viewModel.delete($0) },
                onDeleteDocument: { docsViewModel.deleteDocument($0) }
            )
        }
        // Agenda
        .sheet(isPresented: $showAgenda, onDismiss: {
            if let entry = pendingAgendaEntry {
                pendingAgendaEntry = nil
                editorEntry = entry
            }
        }) {
            AgendaListView(viewModel: viewModel, onTapEntry: { entry in
                pendingAgendaEntry = entry
                showAgenda = false
            })
        }
    }

    /// The month grid with month-paging swipe, shared by the scrolling and
    /// empty (non-scrolling) layouts.
    private var monthGrid: some View {
        MonthGridView(
            month: viewModel.visibleMonth,
            selectedDay: viewModel.selectedDay,
            daysWithEntries: viewModel.daysWithEntries,
            onSelect: { day in
                HapticManager.selection()
                viewModel.selectedDay = day
                // Empty day → jump straight to adding an entry;
                // a day with entries → show its details sheet.
                if viewModel.entries(on: day).isEmpty {
                    showNewEntry = true
                } else {
                    showDayDetail = true
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .gesture(monthSwipe)
    }

    /// Open the editor pre-dated to today.
    private func addEventForToday() {
        viewModel.selectedDay = Calendar.current.startOfDay(for: Date())
        showNewEntry = true
    }

    /// Horizontal swipe on the grid pages between months (left = next, right = previous).
    /// The high horizontal threshold and dominance check keep vertical scrolling intact.
    private var monthSwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 50 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    if value.translation.width < 0 {
                        viewModel.goToNextMonth()
                    } else {
                        viewModel.goToPreviousMonth()
                    }
                }
            }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 46, height: 46)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                Spacer()
                Button { showAgenda = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.textPrimary)
                        .frame(width: 46, height: 46)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
            }

            HStack {
                Text(viewModel.visibleMonth, format: .dateTime.month(.wide).year())
                    .font(.headingL)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if !viewModel.isViewingCurrentMonth {
                    Button { viewModel.goToToday() } label: {
                        Text(L10n.Calendar.today)
                            .font(.labelM)
                            .foregroundStyle(Color.accent)
                    }
                    .padding(.trailing, 12)
                }
                Button { viewModel.goToPreviousMonth() } label: {
                    Image(systemName: "chevron.left").foregroundStyle(Color.textPrimary)
                }
                .padding(.trailing, 12)
                Button { viewModel.goToNextMonth() } label: {
                    Image(systemName: "chevron.right").foregroundStyle(Color.textPrimary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}
