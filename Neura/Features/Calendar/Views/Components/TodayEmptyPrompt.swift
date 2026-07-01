import SwiftUI

/// The persistent "Add Event" call-to-action for the calendar, pinned to the
/// bottom of the screen via `safeAreaInset` so it stays reachable whether or not
/// the day has events. Sits on an opaque bar with a soft top shadow so list
/// content scrolls cleanly underneath it.
struct TodayEmptyPrompt: View {
    let onAdd: () -> Void

    var body: some View {
        PrimaryButton(title: L10n.Calendar.addEvent, systemImage: "", action: onAdd)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
//            .background(
//                Color.backgroundPrimary
//                    .shadow(color: .black.opacity(0.06), radius: 8, y: -4)
//                    .ignoresSafeArea(edges: .bottom)
//            )
    }
}
