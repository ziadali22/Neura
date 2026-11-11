# Meta App Events / App Install Campaigns — Setup

The iOS app side is implemented. The Meta dashboard side requires signing in to Meta
for Developers and Business Manager, so it has to be done by a human with those
credentials. This document covers both halves.

## Status

| Step | State |
|---|---|
| Facebook SDK installed in the iOS app | Done — `facebook-ios-sdk` 18.1.0 via SPM, `FacebookCore` product, Neura app target only |
| SDK initialised at launch | Done — `AppDelegate.application(_:didFinishLaunchingWithOptions:)` |
| App Events enabled | Done — `FacebookAutoLogAppEventsEnabled` + `FacebookAdvertiserIDCollectionEnabled` |
| SKAdNetwork configured | Done — Meta's two identifiers in `SKAdNetworkItems` |
| Standard events wired | Done — see the event table below |
| **Facebook App ID + Client Token** | **Done** — App ID `1022175404063244` + Client Token in `Neura/Info.plist` |
| **Meta App created** | **Done** — connected to Business portfolio + Neura Ads account |
| **Connected to Business Manager + Ad Account** | **Done** |
| **Events verified in Events Manager** | **Ready to verify** — launch on a physical device and check `fb_mobile_activate_app` |
| App Store Connect privacy declarations | **Needs a decision — see Privacy below** |

Verified: `xcodebuild -scheme Neura -sdk iphonesimulator -destination 'generic/platform=iOS
Simulator' build` → `** BUILD SUCCEEDED **`, 0 errors, with `FBSDKCoreKit.framework`
linked. (Note CLAUDE.md's documented build command names an `iPhone 16` simulator that
does not exist on this machine — use a generic destination or an installed device name.)

The SDK is live: App ID `1022175404063244` and the Client Token are in
`Neura/Info.plist`, so `MetaAdsManager` starts the Facebook SDK at launch and
auto-logs `fb_mobile_activate_app`. A leftover `YOUR_*` placeholder would still
keep it off, as a safety gate.

## What you need to do in Meta

Dashboard steps 1–5, 7–9 are done (app created, iOS platform with bundle ID
`com.Neura.health` and App Store ID `6770570586`, credentials in Info.plist,
Business portfolio + Neura Ads account connected). Remaining:

1. **Add the App Events product** if it is not already on: App Dashboard → Add
   Product → *App Events* (may appear as "App Ads"). This is what surfaces the
   app to Ads Manager for App Promotion campaigns.
2. **Configure SKAdNetwork conversion values**: Events Manager → your app →
   *Aggregated Event Measurement* → configure the SKAdNetwork conversion schema.
   Rank the events you want to optimise on (see the table below).

## Verifying events

1. Run the app on a **physical device** (simulator installs are not attributed and
   IDFV behaves differently).
2. Meta App Dashboard → **App Events** → *Test Events* tab, enter the device's
   advertiser ID, or use Events Manager → *Test Events*.
3. Launching the app should produce `fb_mobile_activate_app` within a couple of minutes.
   `MetaAdsManager` flushes the SDK buffer at launch so this is not waiting on the
   default timer; Events Manager can still take a minute or two to display it.
4. Then walk the funnel: finish onboarding → `fb_mobile_tutorial_completion`,
   sign up → `fb_mobile_complete_registration`, open the paywall →
   `fb_mobile_initiated_checkout`, save a document → `document_saved`.

If `fb_mobile_activate_app` never arrives, the usual causes are a wrong Bundle ID in
the App Dashboard, a Client Token from the wrong app, or the App Events product not
having been added.

## Events implemented

All Meta forwarding is centralised in `AnalyticsManager.forwardToMeta` and
`MetaAdsManager`, so no feature code imports the Facebook SDK.

| Meta event | Trigger | Where |
|---|---|---|
| `fb_mobile_activate_app` | install + every launch | Auto-logged by the SDK. **Never hand-logged** — doing so double-counts launches. |
| `fb_mobile_complete_registration` | sign-up finishes, with `method` = apple/google | `AnalyticsEvent.signUpCompleted` |
| `fb_mobile_tutorial_completion` | onboarding finishes | `OnboardingViewModel.finalize()` |
| `fb_mobile_initiated_checkout` | paywall shown | `AnalyticsEvent.paywallViewed` |
| `fb_mobile_purchase` | subscription purchased, with real price + currency | `AnalyticsEvent.subscriptionStarted` |
| `document_saved` (custom) | a document is saved — the app's activation signal | `AnalyticsEvent.documentSaved` |

This is deliberately a short allow-list rather than a mirror of every Mixpanel event.
Meta treats unrecognised event names as custom events, and a large number of them
dilutes the signal that install campaigns optimise against.

`document_saved` is intentionally a *custom* event rather than being forced into a
standard one. No Meta standard event means "saved a document", and mislabelling it as
`fb_mobile_content_view` would pollute a signal the optimiser treats as meaningful. It is
still selectable as an optimisation goal for app-events campaigns.

`fb_mobile_purchase` fires from the app's StoreKit flow. Note Meta only *attributes*
revenue it can tie to an ad click — it does not replace App Store Connect as the
source of truth for subscription revenue.

## Attribution posture (decision made, easy to change)

The app **does not show an App Tracking Transparency prompt**, so ATT status stays
`.notDetermined` and attribution runs through **SKAdNetwork + Meta's Aggregated Event
Measurement**. That is sufficient to run App Install campaigns, optimise for installs,
and see install counts in Ads Manager — it just means coarser, delayed, partly-aggregated
reporting rather than user-level attribution.

Note there is no `Settings.shared.isAdvertiserTrackingEnabled` assignment in the code.
That setter is deprecated and **inert** on Facebook SDK v17+ / iOS 17+ (the build warns
about it) — the SDK reads `ATTrackingManager.trackingAuthorizationStatus` directly. So
adding an ATT prompt later needs no change in `MetaAdsManager`; it only requires:

- an `NSUserTrackingUsageDescription` string in Info.plist,
- an `ATTrackingManager.requestTrackingAuthorization` call at a sensible point in the UX.

This is a product decision with App Store review implications for a health app, so it
was left off by default.

## Privacy — needs your decision before shipping

Neura is in the healthcare category with HealthKit linked, and adding an advertising
SDK changes its privacy posture. Two things are **not** done and should not be guessed at:

1. **`PrivacyInfo.xcprivacy`** — the app has no privacy manifest, and this now matters
   concretely. Inspecting the built product shows the Facebook SDK's own manifest has
   propagated a tracking domain into the app's Info.plist:

   ```
   NSPrivacyTrackingDomains => [ "ep1.facebook.com" ]
   ```

   Apple's rule is that a non-empty `NSPrivacyTrackingDomains` must be accompanied by
   `NSPrivacyTracking = true` in the **app's** privacy manifest — which does not exist
   yet. Left as-is this is a plausible App Store review flag. Note also that declaring
   `NSPrivacyTracking = true` means requests to that domain are blocked unless the user
   has granted ATT, which interacts with the no-ATT-prompt posture above. Worth
   resolving deliberately rather than by default.
2. **App Store Connect → App Privacy** — the data-use answers need updating to reflect
   that an advertiser identifier is now collected and shared with Meta, and whether it
   is used for tracking.

Getting these wrong on a health app risks App Store rejection, so review them with
whoever owns the privacy submission rather than treating them as a formality.
