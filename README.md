# Puli Meka · పులి మేక

**Tiger & Goats**, the traditional board game of Kadapa and Rayalaseema, built with Flutter for Android, iOS, web and Windows.

In villages the board is drawn with chalk on the floor or a stone verandah and played with pebbles and tamarind seeds. The same game is known as *Aadu Puli Aattam* in Tamil Nadu and *Aadu Huli* in Karnataka.

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
| `lib/screens/` | Home, game, rules and statistics screens |
| `lib/widgets/` | Board painter, pieces and decorations |
| `lib/l10n.dart` | English and Telugu text |
