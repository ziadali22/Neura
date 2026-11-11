# Profile Email Capture — Design

## Context

The app has no way to collect a user's email today: `AuthService` (Firebase Auth) doesn't capture one, and there's no marketing list. The goal is to add an email field to the Profile screen and, when the user saves a value, send it to Mixpanel (along with their current subscription status) so it can be used to build a subscriber marketing list.

This is independent of the just-committed `2026-07-09-mixpanel-events-expansion-design.md` spec (centralizing event names into an `AnalyticsEvent` enum) — that work hasn't landed yet, so this feature uses a raw string event name, consistent with all other current call sites.

## Architecture

No dedicated ViewModel exists for the Profile feature — `ProfileView` holds its own `@State`/`@StateObject` and action methods directly (see `handleBiometricToggle`, `handleLogOut`, etc.), so this follows the same pattern rather than introducing a ViewModel.

**New component**: `Neura/Features/Profile/Views/Components/EmailCaptureRow.swift`
- A white card row (matching `BiometricLockRow`'s styling: `Color.surfaceWhite`, 16pt corner radius, subtle shadow) containing a mail icon, a `TextField` bound to the email text, and a checkmark save button.
- The save button is enabled only when the text is non-empty, differs from the currently-persisted value, and passes basic email format validation.
- Invalid input shows small red caption text under the field instead of an alert.
- Placed in `ProfileView`'s existing "Profile" section (`ProfileSectionHeader(title: L10n.Profile.Section.profile)`), above the `Health Profile` / `Subscription` rows. Visible to all users (not gated on Pro status).

New `L10n.Profile` strings needed (added to `en`/`ar`/`ro` `.lproj` files, same as existing Profile strings): field label ("Email"), placeholder text, and the inline validation error message.

**`AnalyticsManager` changes** (`Neura/Core/Services/AnalyticsManager.swift`): add one method:

```swift
func setUserEmail(_ email: String, isSubscribed: Bool) {
    guard isInitialized else { return }
    Mixpanel.mainInstance().people.set(properties: [
        "$email": email,
        "is_subscribed": isSubscribed
    ])
    track("email_submitted", properties: ["is_subscribed": isSubscribed])
}
```

`$email` is Mixpanel's reserved People property, which is what makes the address usable in Mixpanel's People/CRM tooling — not just visible in the raw event log. `is_subscribed` is set on both the People profile (for segmentation) and the event (for filtering in the event log).

## Data Flow

1. User types an email into `EmailCaptureRow` and taps save.
2. `ProfileView` validates the format (basic regex — presence of `@` and a `.` after it, non-empty local/domain parts).
   - Invalid → show inline error, stop. Nothing persisted or sent.
3. Valid → persist to `UserDefaults` under key `neura_user_email` (plain string, no JSON needed) so the field prefills on future visits.
4. Call `AnalyticsManager.shared.setUserEmail(email, isSubscribed: subscriptionManager.isPro)`. `subscriptionManager` is the `SubscriptionManager.shared` instance `ProfileView` already holds.
5. `neura_user_email` is added to the key list cleared in `clearLocalUserData()` (logout/delete account), consistent with the other per-user keys already cleared there.

## Error Handling

Client-side format validation only — no network call is involved, so there's no loading state and no failure mode beyond "invalid format," which is handled inline as described above.

## Testing

No test target exists in this project (per `CLAUDE.md`). Verification is manual: build succeeds, and the save flow is exercised once in the simulator (valid email, invalid email, re-editing an already-saved email, logout clearing the stored value) to confirm no crashes and correct persistence.

## Out of Scope

- Migrating this event to the `AnalyticsEvent` enum from the in-flight Mixpanel expansion spec — that refactor hasn't landed yet; this feature uses a raw string `track` call for now, matching every other existing call site.
- Server-side/CRM export tooling in Mixpanel itself (list building, segments) — out of scope for the app-side change; Mixpanel's People profile is the integration point.
- Gating the field behind Pro status — confirmed the field is visible to all users.
