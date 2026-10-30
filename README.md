# Puli Meka · పులి మేక

**Tiger & Goats**, the traditional board game of Kadapa and Rayalaseema, built with Flutter for Android, iOS, web and Windows.

In villages the board is drawn with chalk on the floor or a stone verandah and played with pebbles and tamarind seeds. The same game is known as *Aadu Puli Aattam* in Tamil Nadu and *Aadu Huli* in Karnataka.

### [⬇️ Download the Android app (APK)](https://github.com/ChandraChaan/Puli-Meka-Game/releases/latest/download/puli-meka.apk)

Free, no ads, no account, works offline. See [all releases](https://github.com/ChandraChaan/Puli-Meka-Game/releases).

## The game

- 23-point board: a triangle crossed by a rectangle.
- 3 tigers start at the top. 15 goats start in hand.
- Goats place one goat per turn, and may only move once all 15 are on the board.
- A tiger steps along a line, or jumps over a single goat into the empty point behind it to capture it.
- Tigers win by capturing 5 goats (you can choose 4 to 7 in Settings). Goats win by trapping all three tigers.
- If the same position comes up three times, the game is a draw.

## Features

- **Play vs Computer** as goats or tigers, at three levels (Easy, Medium, Hard). The computer uses an alpha-beta search on a background isolate.
- **2 Players**: pass and play on one phone.
- **English and Telugu**: the whole app, including the rules, is in both languages.
- Move highlights, red warnings on goats a tiger can capture, hints, and unlimited undo.
- Animated pieces, capture effects, and a marigold petal shower when you win.
- Statistics for games against the computer: wins, losses, draws, win streak, and wins by side and level.
- Indian design touches: a red-oxide floor, a chalk muggulu board, and a mango-leaf thoranam.
- Vibration and click feedback (can be turned off).
- Screen-reader labels for every board point.
- An **About** screen with the app version, privacy note, credits, open-source licences, and links to share the app, get the latest APK, report a problem or read the source.

## Install on Android

Download [`puli-meka.apk`](https://github.com/ChandraChaan/Puli-Meka-Game/releases/latest/download/puli-meka.apk) from the [latest release](https://github.com/ChandraChaan/Puli-Meka-Game/releases/latest) and open it on your phone. If asked, allow your browser or file manager to install unknown apps.

The app ID is `com.chandrachaan.pulimeka`. Builds made before 30 October 2026 used `com.beryapp.beryapp`; if you have one of those, uninstall it, since the new build installs as a separate app.

Every push builds a new APK with GitHub Actions (`.github/workflows/android-apk.yml`) and publishes it on the [Releases](https://github.com/ChandraChaan/Puli-Meka-Game/releases) page: builds from `main` become the latest release, builds from other branches are marked as pre-releases. You can also run the workflow by hand from the **Actions** tab.

### Signing key (recommended)

Without a key, each build is signed with a new throwaway debug key, so Android will not install a new build over an old one; uninstall first. To sign every build with the same key:

1. Create a key once:
   `keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pulimeka`
2. In the repository settings, under **Secrets and variables → Actions**, add:
   - `ANDROID_KEYSTORE_BASE64`: output of `base64 -w0 release.jks`
   - `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`pulimeka`), `ANDROID_KEY_PASSWORD`

Keep `release.jks` safe and never commit it.

### Publishing a build by hand

If GitHub Actions cannot run, build and upload a release from your machine:

```sh
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk puli-meka.apk
gh release create v2.1.0 puli-meka.apk --title "Puli Meka 2.1.0" --latest
```

## Running

```sh
flutter pub get
flutter run            # on a connected phone or emulator
flutter run -d chrome  # in the browser
flutter test
```

## Code layout

| Path | What it holds |
| --- | --- |
| `lib/game/board.dart` | Board geometry: points, lines, neighbours, jumps |
| `lib/game/puli_meka.dart` | Rules engine |
| `lib/game/ai.dart` | Computer opponent |
| `lib/game/game_controller.dart` | Turns, undo, hints, computer moves |
| `lib/screens/` | Home, game, rules, statistics and about screens |
| `lib/widgets/` | Board painter, pieces and decorations |
| `lib/l10n.dart` | English and Telugu text |
