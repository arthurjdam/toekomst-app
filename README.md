# Toekomst

A native iPhone training app built in SwiftUI. It plans a 4-session week (two
full-body conditioning circuits, an upper and a lower mass day), runs the
workout set by set, and tracks bodyweight, lift strength, volume and
consistency against the program rules.

This is the front-end only. Everything that will come from the back-end is
served from JSON fixtures behind a single protocol, so the real API can be
dropped in without touching the screens.

## Requirements

- Xcode 16 or later (the project uses folder-synchronized groups)
- iOS 17 or later, iPhone, portrait, dark appearance

## Running

1. Open `Toekomst.xcodeproj`.
2. Pick an iPhone simulator and run the `Toekomst` scheme.

To run on a device, set your team under Signing & Capabilities and change the
bundle identifier (`app.toekomst.Toekomst` is a placeholder).

The fixtures are anchored to **Thursday 22 October 2026**, the day the design
shows: block 2, week 2, with Lower mass ("Squat + hinge") as today's session.
Settings → Data → "Reset fixture data" restores the starting state.

## Layout

```
Toekomst/                     The iOS app (SwiftUI)
  App/                        App model, tab bar, root navigation
  DesignSystem/               Torque tokens: colors, type, icons, buttons, components
  Features/
    Today/                    Today screen and daily check-in
    Schedule/                 Week schedule, muscle coverage, "pick your days"
    Session/                  Session preview and exercise info
    Workout/                  Player: ready check, exercise, log set, rest,
                              up next, circuit, summary
    Progress/                 Bodyweight, core lifts, volume, consistency
    Settings/
  Resources/                  Fonts (Kode Mono, Barlow; SIL OFL 1.1), asset catalog
Packages/ToekomstKit/         Everything that isn't UI (builds and tests on Linux too)
  Models/                     API-shaped models (Codable, dates as yyyy-MM-dd)
  Logic/                      Week planner, workout engine, session results, rules
  Player/                     WorkoutPlayerModel: the in-workout state machine
  Repository/                 TrainingRepository protocol + fixture implementation
  Fixtures/                   The fake back-end's data
```

## Connecting the back-end

The app only talks to `TrainingRepository`
(`Packages/ToekomstKit/Sources/ToekomstKit/Repository/TrainingRepository.swift`).
Each method is documented with the endpoint it is expected to map to:

| Method | Endpoint |
| --- | --- |
| `today()` | `GET /today` |
| `week(starting:)` | `GET /weeks/{weekStart}` |
| `weekPlanDraft(for:)` | `GET /weeks/{weekStart}/plan` |
| `saveWeekPlan(_:)` | `PUT /weeks/{weekStart}/plan` |
| `session(id:)` | `GET /sessions/{id}` |
| `moveSession(id:to:)` | `POST /sessions/{id}/move` |
| `saveCheckIn(_:)` | `PUT /check-ins/{date}` |
| `progress(range:)` | `GET /progress?range=4w\|12w\|all` |
| `logSession(_:)` | `POST /sessions/{id}/log` |
| `submitFeedback(_:)` | `POST /sessions/{id}/feedback` |

To switch over, write an HTTP implementation of the protocol and return it
from `AppModel.fixtures()` (`Toekomst/App/AppModel.swift`). The request and
response types are the `Codable` models in `Models/`, so they double as a
first draft of the API contract.

`FixtureTrainingRepository` behaves like a small in-memory back-end: weeks are
generated from the weekly template and the chosen training days, and writes
(week plans, moved sessions, check-ins, logged workouts) change what later
reads return. Nothing persists between launches. It also stands in for logic
that belongs on the server, such as progression decisions after a workout
(`SessionResultBuilder`) and muscle coverage per week.

## Design

The screens follow the Torque design system from the design canvas: true
black ground, surfaces stepping up in lightness, Kode Mono for numbers and
labels, Barlow for text, and one accent. Settings can switch the accent
between Volt (yellow) and Greyscale, the two Torque themes.

The program rules from the design spec are encoded in `TrainingRules` and the
logic around it: 4 sessions a week with no back-to-back sessions loading the
same muscles, 10-20 hard sets per muscle group hit at least twice a week, 0-3
reps in reserve as the effort target, load goes up after the top of the rep
range is hit on every set two sessions running, and loads hold when the ready
check reports soreness or low energy. Bodyweight is tracked against +0.25 to
0.5 lb a week.

Motion follows two rules (`Toekomst/DesignSystem/Motion.swift`):

- **Flat** for anything that can interpolate: pages, tabs, progress bars,
  selection highlights, chart data and bar lengths slide, fade, resize or
  recolor on one ease-out curve with no springs, scaling or blur. The workout
  progress bar keeps a single view per exercise, so finishing a set or an
  exercise collapses and widens its slots instead of redrawing the bar.
- **Glitch** for content that swaps rather than moves: labels, numbers,
  status text and demo figures jump sideways in hard steps with a signal
  scan line (about 0.2 s), then settle. Countdown digits tick without
  animation, like a clock.

With Reduce Motion on, page slides become fades and glitches are skipped.

Additions beyond the designed screens:

- Settings tab (auto-start next set, keep screen on, haptics, accent, fixture data)
- Daily check-in sheet, exercise info sheet, lift detail screen
- Rest days, completed sessions and missed sessions on Today and Schedule
- Pause menu (resume, skip a set, end and save, discard)

## Tests

The logic package has unit tests for dates and formatting, the week planner,
training rules, the workout engine, session results, the fixture repository
and the workout player's screen flow:

```sh
cd Packages/ToekomstKit
swift test
```

They also run from Xcode by opening `Packages/ToekomstKit/Package.swift`.
