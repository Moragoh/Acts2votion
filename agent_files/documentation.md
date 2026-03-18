# Acts2votion — Implementation Status

## What has been built

### Shared layer (`Shared/`) ✅
Added to both the `Acts2votion` (main app) and `Act2votionWidgetExtension` targets via `PBXFileSystemSynchronizedRootGroup`.

#### `Shared/Devotional.swift`
Defines the three data models:
- `Devotional` — raw Codable struct that mirrors the JSON exactly (`date`, `type`, `verses`, `content`)
- `ContentSection` — one parsed section: optional `subheading` + array of `bulletPoints`
- `ParsedDevotional` — display-ready model: `date`, `type`, `verses`, `sections`, `rawContent`

#### `Shared/DevotionalParser.swift`
`DevotionalParser` enum with two entry points:
- `buildParsedDevotional(from: Devotional) -> ParsedDevotional` — top-level, skips parsing for `memory_verse` type (returns empty `sections`)
- `parse(content: String) -> [ContentSection]` — splits on `\n`, trims whitespace, drops empty lines, classifies each line as bullet (`•`), valid subheading (matches `^[A-Za-z]+ \d+`), or artifact (silently dropped)

#### `Shared/DevotionalStore.swift`
`DevotionalStore` final class with a `shared` singleton:
- `fetchIfNeeded() async` — checks if today's entry is already cached; if not, fetches from `https://moragoh.github.io/Act2votion-server/devotional.json`, writes to the App Group cache, and calls `WidgetCenter.shared.reloadAllTimelines()`
- `todaysDevotional() -> ParsedDevotional?` — synchronous read; walks back up to 7 days to resolve weekends/missing dates
- Cache location: `<AppGroup container>/Library/Caches/devotionals.json`
- App Group: `group.com.moragoh.act2votion`
- Internal `init(cacheFileURL:)` available for unit tests

### Xcode project (`project.pbxproj`) ✅
- `Shared/` registered as `PBXFileSystemSynchronizedRootGroup` (UUID `ED1E67442F6A1B3E007A9988`)
- `Shared` added to `fileSystemSynchronizedGroups` on both `Acts2votion` and `Act2votionWidgetExtension` targets
- `WidgetKit.framework` linked to the `Acts2votion` main app target (required for `WidgetCenter`)

---

## What still needs to be built

### Main app
- `Acts2votionApp.swift` — remove SwiftData boilerplate; call `DevotionalStore.shared.fetchIfNeeded()` on launch
- `DevotionalView.swift` — scroll view displaying `ParsedDevotional` (verses, sections, bullets) in Georgia font
- `ContentView.swift` — replace with `DevotionalView`
- `Item.swift` — delete (SwiftData leftover)
- Background refresh — `BGAppRefreshTask` wiring for 4 AM EST daily fetch

### Widget extension
- `DevotionalEntry.swift` — `TimelineEntry` wrapping `ParsedDevotional?`
- `DevotionalProvider.swift` — `TimelineProvider`; reads from `DevotionalStore.shared.todaysDevotional()`; refreshes at next 4 AM EST
- `DevotionalWidgetView.swift` — three layouts for `systemSmall`, `systemMedium`, `systemLarge`
- `Act2votionWidget.swift` — replace stub with real `StaticConfiguration` supporting all three sizes
- `Act2votionWidgetBundle.swift` — remove `LiveActivity` registration
- `Act2votionWidget/Info.plist` — widget extension entitlements with App Group `group.com.moragoh.act2votion` (no trailing spaces)

### Entitlements
- `Acts2votion/Acts2votion.entitlements` — strip trailing whitespace from App Group ID (known bug per `architecture.md`)
- Widget extension entitlements file — must be created with clean `group.com.moragoh.act2votion`

### Tests
- `Acts2votionTests/DevotionalParserTests.swift` — unit tests for parsing edge cases
- `Acts2votionTests/DevotionalStoreTests.swift` — unit tests for date resolution and cache read/write
