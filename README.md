# Asla Intervals

A simple interval timer for iOS, focused on Tabata-style workouts. Built with SwiftUI and SwiftData.

## Requirements

- Xcode 26 or newer (Voice Timer uses the iOS 26 SDK)
- iOS 17 or newer (iPhone); Voice Timer needs iOS 26 and Apple Intelligence

## Getting started

1. Open `AslaIntervals.xcodeproj` in Xcode.
2. Select the **AslaIntervals** target → *Signing & Capabilities* → choose your Team (needed to run on a real device; the Simulator works without it).
3. Pick a simulator or your iPhone and press **Run** (⌘R).

The project uses Xcode's folder-synced groups, so any file you add under `AslaIntervals/` is picked up automatically.

## App identity

| | |
|---|---|
| App Store name | Asla Intervals |
| Home Screen name | Asla Intervals |
| Bundle ID | `no.asla.AslaIntervals` |

## Modes

### Simple
- The screen is titled **Timers**, with *Simple mode* underneath.
- Create as many timers as you like (`+` in the top right).
- Switch between Light and Dark mode with the sun/moon button in the top left. Touch and hold it to choose *Use System Setting* again. The choice is remembered. The workout screen uses each timer's own color instead.
- Tap a timer to edit it, swipe left to edit or delete.
- Each timer has:
  | Setting | Range |
  |---|---|
  | Name | – |
  | Number of exercises | 1–20 |
  | Number of rounds | 1–20 |
  | Time per exercise | 5–90 s |
  | Start cooldown | 0–90 s (0 = skipped) |
  | Round cooldown | 0–90 s (0 = skipped, never after the last round) |
  | Workout color | Green (default), Blue, Pink, Red, White or Black. Picked with the swatches under the name |
  | Notes | Free text, max 1000 characters. Control and invisible/bidi characters are removed; text is trimmed and normalized on save |
- Tap **Play** to start. The workout screen shows a large countdown for the current interval and `current / total` intervals (exercises × rounds) below it.
- The background uses the timer's color: full strength while working, a dimmed variant during get ready and rest. Text and ring switch between black and white for contrast. Custom timers use green.
- The ring around the countdown empties clockwise. Inside it, *Exercise N* shows which exercise of the round is running (starting over at 1 each round), or *Next: Exercise N* during get ready and rest.
- Three beeps play on the last three seconds of every interval, and a longer tone when the workout is done. Beeps mix with your music and play even with the silent switch on.
- The screen stays awake while a workout is running.

### Custom
- Same list layout as Simple: tap to edit, swipe to edit or delete, **Play** to start.
- A Custom timer is a list of exercises and rests (each with its own name and length, 5 s – 10 min, up to 30 per round), repeated for 1–20 rounds, with an optional start cooldown and round cooldown (0–300 s).
- The workout screen shows the exercise name, like *Burpees* or *Next: Plank*. A rest at the very end of the last round is skipped.
- Building timers by hand is free.

### Voice Timer (in-app purchase)
- Tap the microphone in Custom mode and describe the workout, for example *"4 rounds of 40 seconds burpees and 20 seconds rest"*. You can also type it.
- Speech is recognized in the iPhone's language when it is Norwegian or English, otherwise in English. Apple Intelligence (Foundation Models, on device) turns the text into a timer, which opens in the editor for review before it is saved.
- Needs iOS 26 and an iPhone with Apple Intelligence turned on. On other iPhones the button is hidden; the rest of the app still supports iOS 17.
- Sold as a one-time purchase with a free 14-day trial. Purchases are handled with StoreKit 2 only – no server.

| Product ID | Type | Price | Name in App Store Connect |
|---|---|---|---|
| `no.asla.AslaIntervals.voicetimer.trial` | Non-Consumable | Free | 14-day Trial |
| `no.asla.AslaIntervals.voicetimer.unlock` | Non-Consumable | Your choice | Voice Timer |

#### Testing purchases in Xcode
1. *Product → Scheme → Edit Scheme… → Run → Options → StoreKit Configuration* → choose `AslaIntervals.storekit`.
2. Run on the Simulator or a device. Purchases are simulated; manage or delete them in *Debug → StoreKit → Manage Transactions*. To test an ended trial, delete the trial transaction and buy it again with the device clock moved back, or change `StoreManager.trialDays` temporarily.
3. Speech recognition needs a real iPhone (the Simulator has no reliable microphone input), and Apple Intelligence needs a supported iPhone with it turned on.

#### Before release
- Sign the Paid Apps Agreement and add banking and tax details in App Store Connect.
- Create both products with the IDs above, add review screenshots, and submit them together with the app version.
- Fill in *App Privacy*: the app uses microphone audio and speech recognition only to set up timers and stores nothing on a server.

## Release to TestFlight

Builds are uploaded by GitHub Actions (`.github/workflows/testflight.yml`) with Xcode automatic signing and an App Store Connect API key. No certificates or profiles are stored anywhere.

1. One-time setup: add the repository secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` (Team key with the Admin role).
2. Start a build from *Actions → TestFlight → Run workflow*, or push a version tag:
   `git tag v1.0.0 && git push origin v1.0.0`
3. The build number is the workflow run number + `BUILD_NUMBER_OFFSET`. Change `MARKETING_VERSION` in Xcode for a new version.
4. After 5–30 minutes of processing by Apple, the build shows up in TestFlight.

## Project layout

```
AslaIntervals/
  App/        App entry point
  Models/     SwiftData models, limits, editor drafts
  Engine/     Workout plans (phases) and countdown engine
  Audio/      Generated beep sounds
  Store/      StoreKit 2 purchases (Voice Timer)
  StoreKit/   StoreKit configuration for testing in Xcode
  Voice/      Speech recognition and Apple Intelligence timer generator
  Views/      SwiftUI screens
```
