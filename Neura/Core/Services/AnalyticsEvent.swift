import Foundation

/// Central registry of Mixpanel event names and property keys. Every event this
/// app sends should have a case here — raw string literals at call sites make
/// typos and duplicate names easy to miss as the event list grows.
enum AnalyticsEvent: String {
    // Existing events, migrated from raw string literals (names unchanged).
    case signUpCompleted = "sign_up_completed"
    case sessionStart = "session_start"
    case folderCreated = "folder_created"
    case documentSaved = "document_saved"
    case calendarEntryCreated = "calendar_entry_created"
    case calendarEntryUpdated = "calendar_entry_updated"
    case calendarEntryCompleted = "calendar_entry_completed"
    case subscriptionStarted = "subscription_started"
    case paywallViewed = "paywall_viewed"
    // NOTE: "onboarding_V{appVersion}_{screen}_completed" stays a dynamically
    // interpolated string at its call site (OnboardingViewModel.swift) — it is
    // not a fixed name, so it isn't represented here.

    // Home
    case homeViewed = "home_viewed"
    case shareHealthProfileTapped = "share_health_profile_tapped"
    case backgroundPickerOpened = "background_picker_opened"
    case secureProfileCardTapped = "secure_profile_card_tapped"
    case completeProfileCardTapped = "complete_profile_card_tapped"
    case emergencyCardTapped = "emergency_card_tapped"
    case appUpdatePromptShown = "app_update_prompt_shown"

    // Profile
    case profileViewed = "profile_viewed"
    case loggedOut = "logged_out"
    case accountDeleted = "account_deleted"
    case biometricToggleChanged = "biometric_toggle_changed"
    case feedbackSheetOpened = "feedback_sheet_opened"
    case languageChanged = "language_changed"
    case subscriptionScreenViewed = "subscription_screen_viewed"
    case emailSubmitted = "email_submitted"

    // Docs
    case docsViewed = "docs_viewed"
    case documentDeleted = "document_deleted"
    case documentsBulkDeleted = "documents_bulk_deleted"
    case addDocumentSheetOpened = "add_document_sheet_opened"
    case documentScanStarted = "document_scan_started"
    case categoryOpened = "category_opened"
    case folderOpened = "folder_opened"
    case documentShareTapped = "document_share_tapped"

    // Dashboard
    case tabSwitched = "tab_switched"
    case floatingMenuOpened = "floating_menu_opened"
    case floatingMenuActionSelected = "floating_menu_action_selected"

    // HealthProfile
    case healthProfileViewed = "health_profile_viewed"
    case healthProfileSaved = "health_profile_saved"

    // Spaces / Accounts
    case spaceCreated = "space_created"
    case spaceSwitched = "space_switched"
    case spaceArchived = "space_archived"
    case spaceAddBlocked = "space_add_blocked"

    // Growth
    case growthViewed = "growth_viewed"
    case growthEntrySaved = "growth_entry_saved"
}

/// Property key constants, reused across events to keep key names consistent.
/// Not every event uses one of these — some (e.g. `document_saved`) keep their
/// pre-existing literal keys ("source", "method", "type"...) unchanged to avoid
/// touching working, already-shipped event schemas.
enum AnalyticsProperty: String {
    case source, category, count, tab, action, enabled, language
}
