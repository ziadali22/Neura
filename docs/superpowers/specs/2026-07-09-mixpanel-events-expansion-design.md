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
    case source, category, count, tab, action, enabled, language
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

### Docs (`Features/Documents/Views/DocsView.swift`, `DocumentsListViewModel.swift`, `Components/DocsFoldersGrid.swift`, `Components/DocumentViewerView.swift`)
| Event | Trigger | Properties |
|---|---|---|
| `docs_viewed` | `DocsView.onAppear` | — |
| `document_deleted` | `DocumentsListViewModel.deleteDocument(_:)` | `category: String` (document's `DocumentCategory` rawValue, or `"none"`) |
| `documents_bulk_deleted` | `DocsView.deleteSelectedDocuments()` | `count: Int` |
| `add_document_sheet_opened` | `DocumentsListViewModel.showAddOptions()`, only when it reaches `showSourcePicker = true` (not the paywall branch) | — |
| `document_scan_started` | `DocumentsListViewModel.startScanning()` | — |
| `category_opened` | tapping a built-in category card (`NavigationLink(value: category)` in `DocsFoldersGrid`) | `category: String` (`DocumentCategory` rawValue) |
| `folder_opened` | tapping a custom folder card (`NavigationLink(value: folder)` in `DocsFoldersGrid`) | — (no folder name — user-authored text) |
| `document_share_tapped` | `DocumentViewerView.shareDocument()` (the standard iOS share sheet action; QR share is separately Pro-gated and still blocked on Firebase per `CLAUDE.md`, not instrumented here) | `category: String` (or `"none"`) |

No document names, dates, folder names, or health content in any property — category/type enums only.

### Dashboard (`Features/Dashboard/Views/Components/CustomTabBar.swift`)
`FloatingDocumentMenu.swift` is dead code (never instantiated outside its own preview — confirmed via grep) and is NOT touched. The live tab-switch and add-menu UI is entirely in `CustomTabBar.swift`.
| Event | Trigger | Properties |
|---|---|---|
| `tab_switched` | `TabSegmentedControl.segment(_:)` button action, when `selectedTab` actually changes | `tab: String` (`"profile"`/`"home"`/`"docs"`, from `AppCoordinator.Tab`) |
| `floating_menu_opened` | `CustomTabBar.fab`, only the `canUpload` branch (menu actually opens; the `onPaywallNeeded` branch is a separate, already-implicit case) | — |
| `floating_menu_action_selected` | `CustomTabBar.fire(_:)` | `action: String` (`"scan"`/`"photo"`/`"file"`, from `AppCoordinator.AddDocumentAction`) |

### HealthProfile (`Features/HealthProfile/Views/HealthProfileDetailView.swift`, `ViewModel/HealthProfileViewModel.swift`)
| Event | Trigger | Properties |
|---|---|---|
| `health_profile_viewed` | `HealthProfileDetailView.onAppear` | — |
| `health_profile_saved` | `HealthProfileViewModel.save()` — the single private chokepoint every mutation (`updateGeneralField`, `addEntry`, `removeSection`, etc.) already funnels through | — |

`fields_updated_count` from the earlier draft is dropped: `save()` has no visibility into which/how many fields changed without threading extra state through ~10 call sites for no clear analytical payoff (YAGNI). Just knowing a save happened is the useful signal.

## Testing

No test target exists in this project (per `CLAUDE.md`). Verification is manual: build succeeds, and each new `track()` call site is exercised once in the simulator to confirm no crashes (Mixpanel calls are fire-and-forget, non-blocking).

## Out of Scope

- Server-side/backend aggregation of document categories (raised as an alternative to per-user health data, not requested for this pass).
- Retrofitting the dynamic onboarding event name into the enum (stays as an interpolated string).
- Analytics for Calendar (already covered) and Paywall (already covered).
