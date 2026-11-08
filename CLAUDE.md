# WatchTamer

A 90s-style virtual pet (dinosaur) for Apple Watch. SwiftUI watchOS app, `WatchTamer.xcodeproj`, target **WatchTamer Watch App**, inside the iPhone wrapper **WatchTamer**, with the complication target **WatchTamerWidgets** (reads `ComplicationData.swift` plans through the App Group `group.com.senalbert.WatchTamer`). English and Spanish (`Localizable.xcstrings`). Bedtime turns the light off by itself and follows the watch's current time zone (`Calendar.autoupdatingCurrent`). Has a privacy manifest. Builds from Xcode show a Testing section in Settings; App Store builds leave it out.

## How Senalbert likes to work

1. Use plain English. When asked, explain step by step. If he says "don't put it in a chart", don't use charts or tables.
2. "Don't do nothing until I tell you" means wait: don't change, build, commit, push or upload anything until he says go.
3. Show pictures before uploading them to the website.
4. Say "iPhone", "iPad" or "Apple Watch", whichever is right, not just "device".
5. Ask before anything that can't be undone.

## Version rules

- 1.0 is the first release, then 1.1, 1.2, and so on.
- Every update gets a "What's New" list (the README's Versions section).
- The build number goes up by 1 on every upload.
- Every update: change the version and build number on the iPhone wrapper target "WatchTamer", the "WatchTamer Watch App" target and the "WatchTamerWidgets" complication, so all three match. Archive with the "WatchTamer" scheme.

## Friend battles must keep working between versions

- Players on different versions (1.0, 1.1 and later) must always be able to battle each other and see the same result.
- Never change BattleCode.swift, the order of the dino species, or anything that decides a friend battle (the code format, the dice, who shoots first, strength, effort, trainings, rare prize) without telling me first and explaining in plain English how older versions would be affected.
- If a future change to battles is really needed, add a version marker to the codes first, so an older watch can say "Update WatchTamer to battle this friend" instead of showing a different result.
- Before every update, test that a battle code made by the previous version and one made by the new version give the same fight on both.

## Senalbert's projects

- App Store apps (release around November 1): WatchTamer, LCD Date, PM & DST, Make Forever QR Codes.
- Downloader: personal use only, never on the App Store.
- Website: apps.senalbert.com (repo apps-website); app support pages live there.
- On hold: Lighthouse Island, Lost Signal: Unit 117. Cancelled: Volt Pair (don't touch it).
- Next up, in order: (1) Attendance web page, (2) sign all four apps and Downloader with the paid developer team so Xcode installs last a year, (3) first App Store upload, step by step.
