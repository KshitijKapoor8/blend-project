# Blend

A UIKit cafe discovery app. Open `blend-project.xcodeproj` in Xcode.

## Discover: location and radius

After login or sign-up, Discover opens first; Profile, Settings, and rating remain available through the Profile tab.

1. Tap **Choose location & radius** (or the current location chip).
2. Enter a city, neighborhood, or address and a radius from **0.5–50 miles**.
3. Tap **Find location**, then select the intended address from the results. This avoids silently choosing an ambiguous city or neighborhood.
4. Discover searches Apple Maps' cafe category, enforces the chosen circular radius using straight-line distance, removes duplicate entries, and lists the remaining cafes nearest first.
5. **Search coffee shops** narrows those results by name. Tap a cafe to open its details in Apple Maps.

The selected location and radius are saved on the device. Manual address input needs no device-location permission or additional API key. Live search requires a network connection. Apple Maps controls search coverage and result limits; this is not an exhaustive database of every cafe. Distances are straight-line distances, not walking or driving routes.

The implementation follows the Excalidraw Discover screen's location/radius chip, search field, Near you list, and existing cream/brown palette. Taste recommendations, match scores, photos, and app ratings need their own data sources and are not fabricated from Maps results. Only Discover and the existing Profile screen have tabs; the other diagram screens are not implemented in this branch.

## Validation

The deterministic checks cover radius boundaries, out-of-radius exclusion, nearest-first ordering, duplicate removal, empty results, changed radius, and invalid/localized radius input. On an Apple Silicon Mac with the macOS 26 SDK:

```sh
xcrun swiftc -target arm64-apple-macos26.0 -module-cache-path /tmp/blend-test-module-cache \
  blend-project/Models/CafeSearch.swift Tests/CafeSearchTests.swift -o /tmp/blend-search-tests
/tmp/blend-search-tests
```

Manual device/simulator checklist:

- Login and sign-up both open Discover; Profile still opens Settings and Rate, and logout returns to login.
- Search a neighborhood such as West Campus, Austin; choose the correct result and compare 0.5-mile and 3-mile results.
- Verify that cafe-name search stays within the selected area; changing location/radius refreshes the list.
- Try blank location, invalid radius, a remote area with no cafes, and offline requests; verify guidance and retry.
- Edit the address while a lookup is in progress; stale results should not replace the edited query.
- Relaunch to verify that the area is restored; open a cafe in Apple Maps.

Validation in the implementation environment: feature/controller Swift type-checking passed against iOS 26 with MainActor default isolation, and all deterministic checks passed. Full Xcode build could not resolve the repository's Firebase 13.0.1 dependency because it requires Swift tools 6.2.1 while the installed Xcode 26.0.1 provides 6.2.0. The project also targets iOS 26.5, newer than the installed 26.0 SDK, and Simulator services were unavailable. Run the full build and manual checklist with a compatible Xcode/iOS runtime. The app's existing Firebase startup requires the ignored `GoogleService-Info.plist` from the project owner; do not commit credentials.
