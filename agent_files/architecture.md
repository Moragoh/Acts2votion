# Acts2votion Architecture

## Overview

iOS SwiftUI devotional app with a WidgetKit home screen widget. The app fetches a JSON array of daily devotionals from a remote endpoint, caches the full array locally in a shared App Group container, and serves today's content to both the main app and the widget from that local cache.

Make sure the app follows the MVVM architecture

**Target:** iOS 17+
**Bundle:** `com.moragoh.act2votion`
**App Group:** `group.com.moragoh.act2votion`

---

## File / Folder Structure

```
Acts2votion/
│
├── Shared/                               ← compiled into both targets
│   ├── Devotional.swift                  ← Codable raw model + ParsedDevotional + ContentSection + VerseComponents
│   ├── DevotionalParser.swift            ← content string → [ContentSection]
│   └── DevotionalStore.swift             ← fetch, cache, read from App Group container
│
├── Acts2votion/                          (Main app target)
│   ├── Acts2votionApp.swift              ← clean entry point, no SwiftData
│   ├── ContentView.swift                 ← thin wrapper around DevotionalView
│   ├── DevotionalView.swift              ← paging TabView + per-page ScrollView
│   ├── DevotionalViewModel.swift         ← @Observable, ViewState, fetch on load
│   └── Acts2votion.entitlements          ← App Group declared
│
├── Act2votionWidget/                     (Widget extension target)
│   ├── Act2votionWidget.swift            ← DevotionalEntry + DevotionalTimelineProvider + Act2votionWidgetEntryView + Act2votionWidget
│   ├── Act2votionWidgetBundle.swift      ← registers Act2votionWidget only
│   ├── Act2votionWidget.entitlements     ← App Group declared
│   └── Assets.xcassets/
│
├── Acts2votionTests/
├── Acts2votionUITests/
└── agent_files/
```

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
struct ParsedDevotional: Identifiable {
    var id: String { date }
    let date: String
    let type: String              // "bible_text" | "memory_verse"
    let verses: String
    let sections: [ContentSection]  // empty for memory_verse (content shown as plain text)
    let rawContent: String          // kept for memory_verse plain display
}
```

`Identifiable` conformance uses `date` as the stable ID, enabling `ForEach` in the paging `TabView`.

### `VerseComponents` + `verseComponents` extension

```swift
struct VerseComponents {
    let bookName: String    // e.g. "1 John"
    let reference: String   // e.g. "4:7-12"
}

extension ParsedDevotional {
    var verseComponents: VerseComponents { ... }
}
```

Strips the parenthetical translation suffix (`" (ESV)"`) then splits on the last space. Handles multi-word book names like "1 John" and "Song of Solomon".

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

- On every app open, `DevotionalViewModel.loadDevotionals()` calls `DevotionalStore.fetchIfNeeded()`. Fetches only if today's entry is missing from cache.
- On success, overwrite the local cache file with the full fetched array.
- After writing, call `WidgetCenter.shared.reloadAllTimelines()` so the widget picks up the fresh data.
- On failure, serve from whatever is cached (silent degradation — show last known data).

### Weekend / missing-date resolution

The JSON only contains entries for weekdays plus occasional memory verse days. When today's date has no matching entry:

1. Walk backwards up to 7 days looking for the most recent entry on or before today.
2. Use that entry. This means on Monday the weekend's last entry (Friday) is shown until a new one arrives.

### `todaysDevotional()` — synchronous read (used by widget)

Reads the local cache file, finds the entry closest to today (using the weekend resolution above), parses it, and returns `ParsedDevotional?`. Called in `getTimeline` and `getSnapshot` — both are off the main thread, so file I/O is fine.

### `allCachedDevotionals()` — full sorted list (used by main app)

Reads the local cache file, parses every entry, and returns `[ParsedDevotional]` sorted by date ascending (ISO-8601 strings sort lexicographically = chronologically). Used by `DevotionalViewModel` to populate the paging `TabView`.

---

## Main App View Hierarchy (`Acts2votion/DevotionalView.swift`)

```
DevotionalView
  └── content (ViewBuilder switch on ViewState)
        ├── .loading  → ProgressView (centered)
        ├── .empty    → Text("No devotional today") (centered)
        └── .loaded   → TabView(.page, indexDisplayMode: .never)
                          └── ForEach(devotionals) → devotionalPage(_:)
                                └── ScrollView (vertical)
                                      ├── dateLabel(for:)          — "MMMM d, yyyy", uppercase, kerned, secondary color
                                      ├── Text(devotional.verses)  — Georgia 20pt, semibold, primary color
                                      ├── Divider
                                      └── if memory_verse:
                                            memoryVerseBody         — Georgia 16pt, italic, centered, secondary color
                                          else:
                                            discussionSections
                                              └── ForEach(sections) → sectionView
                                                    ├── Text(subheading) — Georgia 15pt, semibold
                                                    └── ForEach(bulletPoints) → bulletPointRow
                                                          └── HStack(alignment: .top)
                                                                ├── Text("•") — fixed width 10pt
                                                                └── Text(bullet) — wrapped
```

- Swiping left/right pages through all cached devotionals; vertical scroll works within each page.
- `TabView` selection is bound to `DevotionalViewModel.selectedDateID` — app opens on today's entry (or nearest lookback).
- Bounces at first/last cached entry; no crash on edge swipe.
- Font: `Georgia` (system serif available on all iOS).
- All colors are SwiftUI semantic colors (`Color.primary`, `Color.secondary`, `.tertiary`) — zero custom color definitions. Dark/light mode is handled automatically by the system.

---

## Widget Implementation (`Act2votionWidget/Act2votionWidget.swift`)

All widget components are in a single file.

### `DevotionalEntry`

```swift
struct DevotionalEntry: TimelineEntry {
    let date: Date
    let bookName: String    // e.g. "John"
    let reference: String   // e.g. "8:1-11"
    let isEmpty: Bool       // true when cache is empty
}
```

### `DevotionalTimelineProvider`

Conforms to `TimelineProvider`. Reads from the shared cache via `DevotionalStore.shared.todaysDevotional()`, uses `verseComponents` to split the verse string into `bookName` + `reference`.

**`getTimeline` refresh policy:**
- Generate a single entry for `Date()`.
- Compute next 4 AM EST using `TimeZone(identifier: "America/New_York")` (auto-handles EST/EDT).
- Return `Timeline(entries: [entry], policy: .after(next4amEST))`.

**`placeholder`:** Returns a hardcoded entry with `bookName: "John"`, `reference: "8:1-11"`.

**`getSnapshot`:** Returns a live entry from cache (or empty entry if cache is cold).

### `Act2votionWidgetEntryView`

- Empty state: `"Open app to load"` in Georgia 14pt secondary.
- Loaded state: VStack with book name (Georgia-Bold 16pt primary) over reference (Georgia 14pt secondary), leading-aligned, full-frame.

### `Act2votionWidget` registration

```swift
struct Act2votionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Act2votionWidget", provider: DevotionalTimelineProvider()) { entry in
            Act2votionWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today's Devotional")
        .description("Shows today's devotional book and passage.")
        .supportedFamilies([.systemSmall])
    }
}
```

`Act2votionWidgetBundle` registers only `Act2votionWidget()`.

---

## Background Refresh Strategy

**The app is the sole network fetcher.** The widget only reads from the shared cache — it never makes network calls.

**Network fetch triggers (current):**

1. **App open** → `DevotionalViewModel.loadDevotionals()` calls `DevotionalStore.fetchIfNeeded()`. Fetches only if today's entry is missing from cache.

**Network fetch triggers (planned):**

2. **4 AM EST daily** → `BGAppRefreshTask` calls `DevotionalStore.fetchIfNeeded()`. Wakes the app in the background to pull fresh data even if the user never opens the app. _(Not yet implemented.)_

**Widget refresh triggers:**

1. **After any successful fetch** → `WidgetCenter.shared.reloadAllTimelines()` is called, prompting WidgetKit to immediately request a new timeline and redraw with fresh cache data.
2. **4 AM EST** → WidgetKit timeline policy (`.after(next4amEST)`) causes `getTimeline` to be called. `DevotionalTimelineProvider` reads from the shared cache and returns a new timeline.

**Throttling note:** `reloadAllTimelines()` is only called when a fetch actually writes new data — at most once per day — so it stays well within iOS's daily widget reload budget.

---

## Dark / Light Mode

- All SwiftUI color tokens used are semantic: `Color.primary`, `Color.secondary`, `.background`.
- No custom `Color` assets are defined.
- No explicit `colorScheme` environment checks anywhere.
- The system handles all switching automatically. Zero additional code needed.
