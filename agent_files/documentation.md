# Acts2votion — Implementation Status

## What has been built

### Shared layer (`Shared/`) ✅
Added to both the `Acts2votion` (main app) and `Act2votionWidgetExtension` targets via `PBXFileSystemSynchronizedRootGroup`.

#### `Shared/Devotional.swift`
Defines the data models:
- `Devotional` — raw Codable struct that mirrors the JSON exactly (`date`, `type`, `verses`, `content`)
- `ContentSection` — one parsed section: optional `subheading` + array of `bulletPoints`
- `ParsedDevotional: Identifiable` — display-ready model: `date`, `type`, `verses`, `sections`, `rawContent`; `id` computed from `date` to enable `ForEach` in the paging TabView
- `VerseComponents` — struct holding `bookName` and `reference` split from the `verses` string
- `ParsedDevotional.verseComponents` extension — strips the parenthetical translation suffix (e.g. `" (ESV)"`) then splits on the last space; handles multi-word books like "1 John"

#### `Shared/DevotionalParser.swift`
`DevotionalParser` enum with two entry points:
- `buildParsedDevotional(from: Devotional) -> ParsedDevotional` — top-level, skips parsing for `memory_verse` type (returns empty `sections`)
- `parse(content: String) -> [ContentSection]` — splits on `\n`, trims whitespace, drops empty lines, classifies each line as bullet (`•`), valid subheading (matches `^[A-Za-z]+ \d+`), or artifact (silently dropped)

#### `Shared/DevotionalStore.swift`
`DevotionalStore` final class with a `shared` singleton:
- `fetchIfNeeded() async` — checks if today's entry is already cached; if not, fetches from `https://moragoh.github.io/Act2votion-server/devotional.json`, writes to the App Group cache, and calls `WidgetCenter.shared.reloadAllTimelines()`
- `todaysDevotional() -> ParsedDevotional?` — synchronous read; walks back up to 7 days to resolve weekends/missing dates (used by widget)
- `allCachedDevotionals() -> [ParsedDevotional]` — reads the full cache, parses every entry, returns sorted ascending by date (used by main app to populate the paging TabView)
- Cache location: `<AppGroup container>/Library/Caches/devotionals.json`
- App Group: `group.com.moragoh.act2votion`
- Internal `init(cacheFileURL:)` available for unit tests

### Main app ✅

#### `Acts2votionApp.swift`
Clean entry point — no SwiftData. Renders `ContentView` inside a `WindowGroup`. Fetch is triggered on app open via `DevotionalViewModel.loadDevotionals()` which is called from `DevotionalView`'s `.task` modifier.

#### `ContentView.swift`
Thin wrapper that renders `DevotionalView()`.

#### `DevotionalView.swift`
Paging `TabView` over all cached devotionals. Per-page vertical `ScrollView` driven by `DevotionalViewModel`.
- Navigation header: ZStack with centered date label, hamburger button on left, and conditional Today button on right
  - Today button hidden when `viewModel.isOnToday`; shows `← Today` when current page is ahead of today, `Today →` when behind; tapping calls `viewModel.goToToday()`
  - Date label: uppercase kerned Georgia 12pt secondary
  - Today button label: Georgia 12pt secondary with matching kerning; SF Symbol arrow (size 10) prepended or appended based on direction
- Verse header: Georgia 20pt semibold primary
- Divider separates header from body
- Memory verse: Georgia 16pt italic secondary centered
- Bible text: `discussionSections` → `sectionView` → `bulletPointRow` (HStack with fixed-width `•`)

#### `DevotionalViewModel.swift`
`@Observable @MainActor` class:
- `viewState: ViewState` — `.loading`, `.loaded([ParsedDevotional])`, `.empty`
- `selectedDateID: String` — bound to TabView selection; seeded with today's date (or nearest lookback) by `loadDevotionals()`
- `todayDateID: String` — stored separately from `selectedDateID`; set once in `loadDevotionals()` and never changes during a session; used as the stable reference for "today"
- `isOnToday: Bool` — computed; true when `selectedDateID == todayDateID`; drives Today button visibility
- `todayIsAhead: Bool` — computed; true when `selectedDateID < todayDateID` (ISO strings sort lexicographically); drives Today button arrow direction
- `goToToday()` — sets `selectedDateID = todayDateID`; called by the Today button
- `loadDevotionals()` — calls `fetchIfNeeded()`, then `allCachedDevotionals()`, seeds both `todayDateID` and `selectedDateID`

#### `Acts2votion/Acts2votion.entitlements`
App Group `group.com.moragoh.act2votion` declared. No trailing whitespace issues.

### Widget extension ✅

#### `Act2votionWidget/Act2votionWidget.swift`
All widget components live in this single file:
- `DevotionalEntry: TimelineEntry` — holds `date`, `bookName`, `reference`, `isEmpty`
- `DevotionalTimelineProvider: TimelineProvider` — calls `DevotionalStore.shared.todaysDevotional()`, uses `verseComponents` to split the verse string, returns single-entry timeline with `.after(nextFourAMEST)` refresh policy
- `Act2votionWidgetEntryView` — VStack: book name (Georgia-Bold 16pt primary) over reference (Georgia 14pt secondary); empty state shows "Open app to load"
- `Act2votionWidget` — `StaticConfiguration`, `.supportedFamilies([.systemSmall])`, `.containerBackground(.background, for: .widget)`

#### `Act2votionWidget/Act2votionWidgetBundle.swift`
Registers only `Act2votionWidget()` — `Act2votionWidgetLiveActivity()` removed.

#### `Act2votionWidget/Act2votionWidget.entitlements`
App Group `group.com.moragoh.act2votion` declared. Referenced by both Debug and Release build configurations in `project.pbxproj` via `CODE_SIGN_ENTITLEMENTS`.

### Xcode project (`project.pbxproj`) ✅
- `Shared/` registered as `PBXFileSystemSynchronizedRootGroup` (UUID `ED1E67442F6A1B3E007A9988`)
- `Shared` added to `fileSystemSynchronizedGroups` on both `Acts2votion` and `Act2votionWidgetExtension` targets
- `WidgetKit.framework` linked to the `Acts2votion` main app target (required for `WidgetCenter`)
- `CODE_SIGN_ENTITLEMENTS = Act2votionWidget/Act2votionWidget.entitlements` added to both Debug and Release build configurations for `Act2votionWidgetExtension`

---

## What still needs to be built

### Main app
- Background refresh — `BGAppRefreshTask` wiring for 4 AM EST daily fetch (app currently only fetches on open via ViewModel)

### Tests
- `Acts2votionTests/DevotionalParserTests.swift` — unit tests for parsing edge cases
- `Acts2votionTests/DevotionalStoreTests.swift` — unit tests for date resolution and cache read/write
