# Blend

## Contributions

| Team Member | Contributions |
|---|---|
| **Karnika Choudhury (25%)** | • Linked Firebase backend to the project<br>• Set up storage bucket for profile picture images<br>• Added ability to change profile picture and bio in Settings, updating the user model |
| **Kshitij Kapoor (25%)** | • Created much of the UI<br>• Implemented the rate coffee shops functionality |
| **Aarnawa Koirala (25%)** | • Set up Firebase/Firestore<br>• Set up the users model and created the Blend app<br>• Created the register/login page |
| **Pranav Tonpe (25%)** | • Created the Discover page, with the ability to search coffee shops by radius and city location |

## Deviations

- **Discover radius:** The Discover page should use the radius stored in the user's profile. This is a minor fix planned for the next release.
- **Ratings:** For now, the proper coffee shop feed is not built so a user's own ratings are simply stored in their profile. We are unsure if we will keep this UI but it demonstrates the functionality for the alpha release. The optional adding of pictures is also not yet fully functional. Bug fix and decision regarding UI will be finalized in beta.

## Beta: Friends and Maps

- **Friends:** Open the tab or tap the Friends card in Profile. In **Find**, enable discovery and search for a teammate's exact username. Both accounts need to opt in before a request can be sent. **Requests** separates received and sent requests. The recipient can accept or decline, the sender can cancel, and either friend can remove the connection. Pull to refresh for updates. Profile counts accepted friends.
- **Maps:** In **Discover**, pick a location and radius, then switch between **List** and **Map**. The same café results and name filter power both views. The map outlines the selected radius, pins matching shops, and can recenter after panning. Open a list row or a pin's details button to view the place or get walking directions in Apple Maps. Edit the radius in place with **Apply radius**. No extra map key or device-location permission is needed.

### Firebase setup for Friends

The existing app still needs its local, ignored `GoogleService-Info.plist`. Friends uses two new collections, `friendDirectory` and `friendConnections`. Before testing Friends against a shared Firebase project, have the project owner merge the Friends functions and collection matches from `firebase/friends.rules` into the existing `/databases/{database}/documents` match in that project's Firestore rules. Preserve the existing users and ratings rules and check that no overlapping wildcard grants broader access to the new collections. **Do not replace the deployed rules with this file**; it is standalone for the emulator tests. No production rules or records were changed by this branch.

The opt-in directory holds only name and username fields and is readable by signed-in Blend members. Email, phone, and private profile fields are never copied. Only the two participants can read a connection; its display names and usernames are retained for them while a request or friendship exists, even if one person hides from discovery. Firestore enforces a single document per pair and only the recipient can accept a pending request.

### Verify

With compatible Xcode and Firebase configured, try two beta accounts: enable discovery on both, send a request, accept it on the other account, then check the Friends list and Profile count. Also try declining, canceling, removing a friend, and hiding an account from search. For Discover, search near West Campus, Austin, compare pins and list results, change the name filter and radius, and open walking directions.

Run the rules tests with Node.js and Java against the local Firestore emulator:

```sh
test_dir="$(mktemp -d)"
cp firebase/{friends.rules,friends.rules.test.mjs,emulator.json} "$test_dir/"
cd "$test_dir"
npm install firebase-tools@14.27.0 @firebase/rules-unit-testing@5.0.0 firebase@12.6.0
npx firebase emulators:exec --config emulator.json --project demo-blend-friends --only firestore 'node --test friends.rules.test.mjs'
```

Run the deterministic café filtering checks on an Apple Silicon Mac with the macOS 26 SDK:

```sh
xcrun swiftc -target arm64-apple-macos26.0 -module-cache-path /tmp/blend-test-module-cache \
  blend-project/Models/CafeSearch.swift Tests/CafeSearchTests.swift -o /tmp/blend-search-tests
/tmp/blend-search-tests
```
