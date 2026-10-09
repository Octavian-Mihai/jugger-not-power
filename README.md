# Ferrum

A personalized strength-training coach for iOS. Generate a program around your lifts and schedule, or build your own from scratch. Ferrum adjusts the day's training from a readiness check-in and from how each set actually felt.

## Features
- **Generated programs**: powerlifting, powerbuilding, PowerCombo and full-body, built from your days per week, experience and optional muscle emphasis.
- **Custom programs**: build blocks, days and exercises yourself, or fork a generated program and edit it. Sets can be prescribed as % of 1RM, RPE/RIR targets, rep ranges with double progression, or fixed weight.
- **Readiness check-in**: sleep, energy, mood and soreness scale the day's load, sets and target RIR.
- **Performance-based adjustment**: log weight, reps and RIR; the next set is re-aimed from the estimated 1RM, and rep-range lifts progress automatically.
- **Progress**: estimated 1RM trends, hard sets per muscle, PRs.
- **Exercise library**: 143 exercises with images, muscles and cues, plus muscle and RIR guides.
- kg/lb, three themes (Forge, Chalk, Volt), all data stored on device.

## Layout
| Path | What |
| --- | --- |
| `Ferrum/` | SwiftUI app (SwiftData models, views, resources) |
| `Packages/FerrumCore/` | Pure Swift training engine with unit tests (`swift test`) |
| `Resources/ExerciseLibrary/` | Source markdown and images for the exercise library |
| `scripts/build_library.py` | Converts the library markdown to `Ferrum/Resources/*.json` and flat images |
| `project.yml` | XcodeGen spec |

## Build
```bash
python3 scripts/build_library.py   # only when the library markdown changes
xcodegen generate
open Ferrum.xcodeproj
```
Engine tests: `cd Packages/FerrumCore && swift test`.

## Program builder website
`web/` is a standalone page for writing a program on a computer. Open `web/index.html` in a browser (no server or build step), build blocks, days and exercises, then **Download for Ferrum**. In the app: Programs → **Import from file**. The same menu exports any program as a `.ferrum.json` file. The file format is documented in `Packages/FerrumCore/Sources/FerrumCore/Interchange.swift`.
