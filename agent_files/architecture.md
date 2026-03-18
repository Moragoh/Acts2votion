# Acts2votion Architecture

## Overview

iOS SwiftUI devotional app with a WidgetKit home screen widget. The app fetches a JSON array of daily devotionals from a remote endpoint, caches the full array locally in a shared App Group container, and serves today's content to both the main app and the widget from that local cache.

Make sure the app follows the MVVM architecture

**Target:** iOS 17+
**Bundle:** `com.moragoh.act2votion`
**App Group:** `group.com.moragoh.act2votion` _(see Known Bugs below)_

---

## File / Folder Structure

```
Acts2votion/
│
├── Shared/                               ← NEW GROUP (added to both targets)
│   ├── Devotional.swift                  ← NEW: Codable raw model + ParsedDevotional + ContentSection
│   ├── DevotionalParser.swift            ← NEW: content string → ParsedDevotional
│   └── DevotionalStore.swift             ← NEW: fetch, cache, read from App Group container
│
├── Acts2votion/                          (Main app target)
│   ├── Acts2votionApp.swift              ← MODIFIED: remove SwiftData, add fetch-on-launch
│   ├── ContentView.swift                 ← MODIFIED: replaced entirely with DevotionalView
│   ├── DevotionalView.swift              ← NEW: main app scroll view
│   ├── Acts2votion.entitlements          (existing — App Group already declared)
│   └── Assets.xcassets/
│
├── Act2votionWidget/                     (Widget extension target)
│   ├── Act2votionWidget.swift            ← MODIFIED: real StaticConfiguration, 3 sizes
│   ├── Act2votionWidgetBundle.swift      ← MODIFIED: remove LiveActivity registration
│   ├── DevotionalEntry.swift             ← NEW: TimelineEntry with ParsedDevotional?
│   ├── DevotionalProvider.swift          ← NEW: TimelineProvider, 4 AM refresh
│   ├── DevotionalWidgetView.swift        ← NEW: views for small / medium / large
│   └── Assets.xcassets/
│
├── Acts2votionTests/
├── Acts2votionUITests/
└── agent_files/
```

**Files changed summary:**

- **New:** 7 (`Shared/Devotional.swift`, `Shared/DevotionalParser.swift`, `Shared/DevotionalStore.swift`, `Acts2votion/DevotionalView.swift`, `Act2votionWidget/DevotionalEntry.swift`, `Act2votionWidget/DevotionalProvider.swift`, `Act2votionWidget/DevotionalWidgetView.swift`)
- **Modified:** 4 (`Acts2votionApp.swift`, `ContentView.swift`, `Act2votionWidget.swift`, `Act2votionWidgetBundle.swift`)
- **Deleted:** 2 (`Acts2votion/Item.swift`, `Act2votionWidget/Act2votionWidgetLiveActivity.swift`)

> The `Shared/` folder must be created as a new Xcode group with all three files added to **both** the main app target and the widget extension target.

---

## Data Model (`Shared/Devotional.swift`)

### `Devotional` — raw Codable, mirrors JSON exactly

```swift
struct Devotional: Codable {
    let date: String      // "2026-01-19"
    let type: String      // "bible_text" | "memory_verse"
    let verses: String    // "John 8:1-11 (ESV)"
    let content: String   // raw string with \n delimiters
}
```

### `ContentSection` — one parsed section of content

```swift
struct ContentSection {
    let subheading: String?       // nil when content starts with a bullet (no heading)
    let bulletPoints: [String]    // bullet text with leading "• " stripped
}
```

### `ParsedDevotional` — ready-to-display model

```swift
struct ParsedDevotional {
    let date: String
    let type: String              // "bible_text" | "memory_verse"
    let verses: String
    let sections: [ContentSection]  // empty for memory_verse (content shown as plain text)
    let rawContent: String          // kept for memory_verse plain display
}
```

---

## Content Parsing Strategy (`Shared/DevotionalParser.swift`)

Input: the `content` string from JSON.
Output: `[ContentSection]`.

**Algorithm:**

1. Split the content string on `"\n"`.
2. Strip any trailing whitespace from every line (artifact filtering).
3. Drop any empty lines produced by split.
4. Also drop artifact lines that contain no bullet and look like a sentence fragment before the first bullet — detected as: the first line does not start with `"•"` **and** contains no colon/chapter reference pattern (e.g., `"tetelestai) signifies…"` from `2026-04-01`). This is handled by: if a line has no `"•"` and no digit, treat it as a potentially dirty prefix — skip it when building sections.
   _(Simpler heuristic: a subheading line must match `[A-Za-z]+ \d+` — a book name followed by a chapter/verse number. Otherwise treat it as an artifact and drop it.)_
5. Walk lines sequentially:
   - If a line does **not** start with `"•"` → it is a subheading. Start a new `ContentSection` with that subheading.
   - If a line **does** start with `"•"` → append to the current section's bullet list. If no section exists yet, create one with `subheading: nil`.

**Edge cases:**

- `2026-02-12`: content starts directly with `•` → first `ContentSection` has `subheading: nil`.
- `2026-04-01`: content starts with a sentence fragment artifact → dropped by the subheading validity check; remaining bullets still parsed correctly.
- `memory_verse` type: content is a plain quote string with no subheadings or bullets → `sections` is `[]`; `rawContent` is displayed as-is.

---

## Networking + Caching (`Shared/DevotionalStore.swift`)

### Shared container

- App Group identifier: `group.com.moragoh.act2votion`
- Cache file path: `<AppGroup container>/Library/Caches/devotionals.json`
- Both the main app and widget extension read/write through this path.

### Fetch strategy

- On every app launch, `DevotionalStore` checks whether today's devotional is already in the local cache (compare today's date string against cached array).
- If today's entry is **missing** (or cache does not exist), perform a `URLSession` fetch from `https://moragoh.github.io/Act2votion-server/devotional.json`.
- On success, overwrite the local cache file with the full fetched array.
- After writing, call `WidgetCenter.shared.reloadAllTimelines()` so the widget picks up the fresh data.
- On failure, serve from whatever is cached (silent degradation — show last known data).

### Weekend / missing-date resolution

The JSON only contains entries for weekdays plus occasional memory verse days. When today's date has no matching entry:

1. Walk backwards up to 7 days looking for the most recent entry on or before today.
2. Use that entry. This means on Monday the weekend's last entry (Friday) is shown until a new one arrives.

### `todaysDevotional()` — synchronous read (used by widget)

Reads the local cache file, finds the entry closest to today (using the weekend resolution above), parses it, and returns `ParsedDevotional?`. This is called in `getTimeline` and `getSnapshot` — both are off the main thread, so file I/O is fine.

---

## Main App View Hierarchy (`Acts2votion/DevotionalView.swift`)

```
DevotionalView
  └── ScrollView (vertical)
        ├── Text(devotional.verses)          — font: .custom("Georgia", …), large, primary color
        ├── Divider
        └── ForEach(devotional.sections)
              ├── Text(section.subheading)   — font: .custom("Georgia", …), semibold, primary color
              └── ForEach(section.bulletPoints)
                    └── HStack(alignment: .top)
                          ├── Text("•")     — leading, fixed width
                          └── Text(bullet)  — wrapped
```

- Single `ScrollView` — no `NavigationView`, no tabs, no lists.
- Font: `Georgia` (system serif available on all iOS). This is the closest system font to Times New Roman.
- All colors are SwiftUI semantic colors (`Color.primary`, `Color.secondary`, `Color.background`) — zero custom color definitions. Dark/light mode is handled automatically by the system.
- Loading/error states: a simple centered `Text("Loading…")` or `Text("No devotional today")` placeholder.

---

## Widget Implementation

### `DevotionalEntry` (`Act2votionWidget/DevotionalEntry.swift`)

```swift
struct DevotionalEntry: TimelineEntry {
    let date: Date
    let devotional: ParsedDevotional?   // nil → show placeholder
}
```

### `DevotionalProvider` (`Act2votionWidget/DevotionalProvider.swift`)

Conforms to `TimelineProvider`. Reads from the shared cache via `DevotionalStore.todaysDevotional()`.

**`getTimeline` refresh policy:**

- Generate a single entry for `Date()`.
- Compute the next 4 AM EST: if current time is before 4 AM EST today, use today at 4 AM EST; otherwise use tomorrow at 4 AM EST.
- Return `Timeline(entries: [entry], policy: .after(next4amEST))`.
- This means WidgetKit will ask for a new timeline once per day at 4 AM EST.

**`placeholder`:** Returns a `DevotionalEntry` with a hardcoded placeholder `ParsedDevotional` (no network call).

**`getSnapshot`:** Returns `DevotionalEntry` from cache (or placeholder if cache is empty).

### `DevotionalWidgetView` (`Act2votionWidget/DevotionalWidgetView.swift`)

Three layouts driven by `entry.family` via `@Environment(\.widgetFamily)`:

| Size           | Content                                                                                      |
| -------------- | -------------------------------------------------------------------------------------------- |
| `systemSmall`  | Verse reference only (`devotional.verses`), centered, serif font                             |
| `systemMedium` | Verse reference + first subheading + first bullet point, truncated with `lineLimit`          |
| `systemLarge`  | Verse reference + all sections (subheadings + all bullets), truncated gracefully if overflow |

All three use `.containerBackground(.fill.tertiary, for: .widget)` (iOS 17+).

### `Act2votionWidget` registration (`Act2votionWidget/Act2votionWidget.swift`)

```swift
struct Act2votionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Act2votionWidget", provider: DevotionalProvider()) { entry in
            DevotionalWidgetView(entry: entry)
        }
        .configurationDisplayName("Acts2votion")
        .description("Today's devotional verse.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

`Act2votionWidgetBundle` registers only `Act2votionWidget()` — the `LiveActivity` registration is removed.

---

## Background Refresh Strategy

**The app is the sole network fetcher.** The widget only reads from the shared cache — it never makes network calls.

**Network fetch triggers:**

1. **App launch** → `Acts2votionApp.onAppear` calls `DevotionalStore.fetchIfNeeded()`. Fetches only if today's entry is missing from cache.
2. **4 AM EST daily** → `BGAppRefreshTask` calls `DevotionalStore.fetchIfNeeded()`. Wakes the app in the background to pull fresh data even if the user never opens the app.

**Widget refresh triggers:**

1. **After any successful fetch** → `WidgetCenter.shared.reloadAllTimelines()` is called, prompting WidgetKit to immediately request a new timeline and redraw with fresh cache data.
2. **4 AM EST** → WidgetKit timeline policy (`.after(next4amEST)`) causes `getTimeline` to be called. `DevotionalProvider` reads from the shared cache (which `BGAppRefreshTask` has already updated) and returns a new timeline.

**Throttling note:** `reloadAllTimelines()` is only called when a fetch actually writes new data — at most once per day — so it stays well within iOS's daily widget reload budget.

**Result:** Widget is guaranteed to show fresh content by 4 AM daily, and also updates immediately when the user opens the app.

---

## Dark / Light Mode

- All SwiftUI color tokens used are semantic: `Color.primary`, `Color.secondary`, `.background`, `.fill.tertiary`.
- No custom `Color` assets are defined.
- No explicit `colorScheme` environment checks anywhere.
- The system handles all switching automatically. Zero additional code needed.

---

## Known Bug

**Trailing whitespace in entitlements App Group ID**

In `Acts2votion/Acts2votion.entitlements`, the App Group identifier has trailing spaces:

```xml
<string>group.com.moragoh.act2votion          </string>
```

The widget extension's entitlements file (if/when created) must use the **exact same string including trailing spaces**, or the shared container lookup will silently fail and both targets will read from separate sandboxed containers. The fix is to strip the trailing whitespace from the main app entitlements and ensure the widget entitlements file uses the clean string `group.com.moragoh.act2votion`.

**Action required before coding:** Fix this in `Acts2votion.entitlements` and ensure the widget extension entitlements file (to be created) uses `group.com.moragoh.act2votion` with no extra whitespace.
