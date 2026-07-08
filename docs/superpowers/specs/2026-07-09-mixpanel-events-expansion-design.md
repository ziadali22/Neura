# Mixpanel Events Expansion — Design

## Context

Mixpanel is already live in the app (`Core/Services/AnalyticsManager.swift`, real project token, `trackAutomaticEvents: false`). Only 9 events exist today, all as raw string literals with no shared naming convention:

- `onboarding_V{appVersion}_{screen}_completed`, `sign_up_completed` (Onboarding)
- `session_start` (Dashboard)
- `folder_created`, `document_saved` (Documents)
- `calendar_entry_created`/`updated`/`completed` (Calendar)
- `subscription_started` (SubscriptionManager)
- `paywall_viewed` (Paywall)

Home and Profile tabs have **zero** tracking. Docs has partial coverage. This spec adds screen-view and key-action tracking across Home, Profile, Docs, Dashboard, and HealthProfile, and centralizes event/property names.

**Explicitly out of scope / rejected**: sending disease names, diagnoses, health report contents, or city/location tied to health data to Mixpanel. Mixpanel attaches a `distinct_id` (+ device/IP) to every event, so any health-condition field would be identifiable PHI sent to a third party without a BAA or user consent — rejected regardless of what other fields accompany it.

This also rules out any **free-text, user-authored string** as a property value, not just literal disease names — a folder or document name typed by a user in a health app carries the same risk (e.g. a folder named "Diabetes meds"). The only string properties sent are raw values of fixed, app-defined enums the user picks from (e.g. `DocumentCategory`: Blood Tests, Prescriptions, Imaging, etc.), never user-typed text. `MedicalSpecialization` (Oncology, Psychiatry, etc.) is also excluded even though it's a fixed enum, since it's diagnosis-adjacent. `doctorName`, `notes`, `tags`, and document/folder names are never sent.

**Fixing a pre-existing leak**: the current `folder_created` event (`DocsView.swift:115-116`) sends the raw user-typed `folder_name`. Since this pass centralizes analytics, this call site is updated to drop `folder_name` and keep only `total_folders` — leaving it in place while refusing `disease` elsewhere wouldn't be consistent.

## Architecture

New file: `Core/Services/AnalyticsEvent.swift`

```swift
enum AnalyticsEvent: String {
    // existing (migrated from string literals, no name changes)
    case signUpCompleted = "sign_up_completed"
    case sessionStart = "session_start"
    case folderCreated = "folder_created"
    case documentSaved = "document_saved"
    case calendarEntryCreated = "calendar_entry_created"
    case calendarEntryUpdated = "calendar_entry_updated"
    case calendarEntryCompleted = "calendar_entry_completed"
    case subscriptionStarted = "subscription_started"
    case paywallViewed = "paywall_viewed"
    // onboarding_V{version}_{screen}_completed stays dynamic (interpolated), not an enum case

    // new — see event tables below
    ...
}

enum AnalyticsProperty: String {
    case source, category, folder, count, tab, action, enabled, language
}
```

`AnalyticsManager` gains an overload:

```swift
func track(_ event: AnalyticsEvent, properties: [String: MixpanelType]? = nil) {
    track(event.rawValue, properties: properties)
}
```

The existing `track(_ event: String, ...)` stays (used for the dynamic onboarding event name). All 9 existing call sites are migrated to use `AnalyticsEvent` cases instead of string literals — no behavioral change, just centralization.

## New Events

Naming convention: snake_case, past-tense for completed actions (`_completed`, `_saved`, `_deleted`), `_viewed` for screen appearances, `_tapped`/`_opened` for UI interactions, `_changed` for toggles/settings.

### Home (`Features/Home/Views/HomeView.swift`)
| Event | Trigger | Properties |
|---|---|---|
| `home_viewed` | `.onAppear` | — |
| `share_health_profile_tapped` | share sheet opens | `source: "home"` |
| `background_picker_opened` | picker sheet opens | — |
| `secure_profile_card_tapped` | card tap | — |
| `complete_profile_card_tapped` | card tap | — |
| `emergency_card_tapped` | banner tap | — |
| `app_update_prompt_shown` | update sheet shown | — |

### Profile (`Features/Profile/Views/ProfileView.swift`)
| Event | Trigger | Properties |
|---|---|---|
| `profile_viewed` | `.onAppear` | — |
| `logged_out` | after successful `handleLogOut` | — |
| `account_deleted` | after successful `handleDeleteAccount` | — |
| `biometric_toggle_changed` | `handleBiometricToggle` | `enabled: Bool` |
| `feedback_sheet_opened` | `showFeedback` set true | — |
| `language_changed` | language picker selection | `language: String` |
| `subscription_screen_viewed` | tapped from profile | `source: "profile"` |

### Docs (`Features/Documents/Views/DocsView.swift`, `DocumentsListViewModel.swift`)
| Event | Trigger | Properties |
|---|---|---|
| `docs_viewed` | `.onAppear` | — |
| `document_deleted` | `deleteDocument()` | `category: String`, `source` |
| `documents_bulk_deleted` | `deleteSelectedDocuments()` | `count: Int` |
| `document_scan_started` | `scanFromFolder()` / scan tab entry | `source: String` |
| `add_document_sheet_opened` | add sheet opens | — |
| `category_filter_selected` | category picker changes | `category: String` |
| `folder_filter_selected` | folder picker changes | `folder_filter_active: Bool` (no folder name) |
| `share_document_tapped` | share menu item tapped | `category: String` |

No document names, dates, or health content in any property — category/type enums only.

### Dashboard (`Features/Dashboard/Views/DashboardView.swift`, `CustomTabBar.swift`, `FloatingDocumentMenu.swift`)
| Event | Trigger | Properties |
|---|---|---|
| `tab_switched` | tab bar selection changes | `tab: String` |
| `floating_menu_opened` | + button tapped | — |
| `floating_menu_action_selected` | scan/photo/file chosen | `action: String` |

### HealthProfile (`Features/HealthProfile/`)
| Event | Trigger | Properties |
|---|---|---|
| `health_profile_viewed` | detail view `.onAppear` | — |
| `health_profile_saved` | save action completes | `fields_updated_count: Int` |

No field names or values — only a count of how many fields changed.

## Testing

No test target exists in this project (per `CLAUDE.md`). Verification is manual: build succeeds, and each new `track()` call site is exercised once in the simulator to confirm no crashes (Mixpanel calls are fire-and-forget, non-blocking).

## Out of Scope

- Server-side/backend aggregation of document categories (raised as an alternative to per-user health data, not requested for this pass).
- Retrofitting the dynamic onboarding event name into the enum (stays as an interpolated string).
- Analytics for Calendar (already covered) and Paywall (already covered).
