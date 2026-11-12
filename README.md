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

## Beta: Feed

- **Feed:** The Feed tab lists your accepted friends' ratings, newest first. A rating with a comment or photo is a full card with the overall score, the three highest category scores, and the comment. Other ratings are one line: "tried a new spot" for a first rating (numbered by how many shops that friend has rated) or "is back at" for a shop they rated again. The button in the top right opens Friends. Pull to refresh.
- **Likes:** Tap the heart on a full card to like or unlike it. Each rating stores a `likedBy` list of user IDs, and the count is its length. Friends can add or remove only their own ID, and liking doesn't move the post in the feed.
- **Unique usernames:** Sign-up now claims `usernames/{lowercased username}` together with the profile, because the rules don't allow searching other people's profiles. Usernames are 1–30 letters, numbers, or underscores. Accounts created earlier register their username the next time they log in.

### Firebase setup

The app still needs its local, ignored `GoogleService-Info.plist`. `firebase/firestore.rules` is the complete Firestore ruleset for the shared project: users, usernames, ratings, and Friends. To deploy, paste it into the Firebase console (Firestore Database → Rules) and publish. Edit rules in this file first so the deployed rules and the emulator tests stay the same.

- **Ratings** can be read by their owner and by accepted friends (for Feed). Only the owner can change or delete one, except that friends can add or remove their own like. Listing every rating in the project is not allowed.
- **Usernames** can be checked by any signed-in member and created once, only by the account whose profile has that username.

Friends search only finds members who turned on discovery. Accounts created before Friends existed need to open Friends → Find → **Enable friend discovery** before others can find them. Enabling requires a `name` and `username` in the user's profile. Very early accounts may be missing `name`, which shows "Your Blend profile is missing a name or username"; add the field to that user's document in the console.

The opt-in directory holds only name and username fields and is readable by signed-in Blend members. Email, phone, and private profile fields are never copied. Only the two participants can read a connection; its display names and usernames are retained for them while a request or friendship exists, even if one person hides from discovery. Firestore enforces a single document per pair and only the recipient can accept a pending request.

### Verify

With compatible Xcode and Firebase configured, try two beta accounts: enable discovery on both, send a request, accept it on the other account, then check the Friends list and Profile count. Also try declining, canceling, removing a friend, and hiding an account from search. Once two accounts are friends, rate a shop on one (with and without a comment) and pull to refresh Feed on the other. Try signing up with a username that's already taken, in different capitalization. For Discover, search near West Campus, Austin, compare pins and list results, change the name filter and radius, and open walking directions.

Run the rules tests with Node.js and Java against the local Firestore emulator:

```sh
test_dir="$(mktemp -d)"
cp firebase/{firestore.rules,*.rules.test.mjs,emulator.json} "$test_dir/"
cd "$test_dir"
npm install firebase-tools@14.27.0 @firebase/rules-unit-testing@5.0.0 firebase@12.6.0
npx firebase emulators:exec --config emulator.json --project demo-blend --only firestore \
  'node --test friends.rules.test.mjs feed.rules.test.mjs usernames.rules.test.mjs'
```

Run the deterministic café filtering and feed checks on an Apple Silicon Mac with the macOS 26 SDK:

```sh
xcrun swiftc -target arm64-apple-macos26.0 -module-cache-path /tmp/blend-test-module-cache \
  blend-project/Models/CafeSearch.swift Tests/CafeSearchTests.swift -o /tmp/blend-search-tests
/tmp/blend-search-tests
xcrun swiftc -target arm64-apple-macos26.0 -module-cache-path /tmp/blend-test-module-cache \
  blend-project/Models/FeedItem.swift blend-project/Models/FriendConnection.swift Tests/FeedItemTests.swift -o /tmp/blend-feed-tests
/tmp/blend-feed-tests
```
