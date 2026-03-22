# Multiple DT Cards — Implementation Plan

## Context
The app currently shows a single devotional (today or nearest lookback). Users want to swipe left/right to browse previous and future cached devotionals. We'll use SwiftUI's `TabView` with `.page` style for native iOS paging, bounce at edges, and smooth transitions.

## Decisions
- **Swipe mechanism:** `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))`
- **Range:** All cached dates (no filtering)
- **Date header:** Shows the currently displayed devotional's date (not always today)

---

## Step 1: `Shared/Devotional.swift` — Make `ParsedDevotional` Identifiable

Add `Identifiable` conformance using `date` as the `id`:

```swift
struct ParsedDevotional: Identifiable {
    var id: String { date }
    // ... existing properties unchanged
}
```

This lets `ForEach(devotionals)` work in the `TabView`. No changes to `Devotional` or `ContentSection`.

---

## Step 2: `Shared/DevotionalStore.swift` — Add `allCachedDevotionals()`

Add one new public method. `loadCachedDevotionals()` stays private.

```swift
/// Returns all cached devotionals, parsed and sorted by date ascending.
func allCachedDevotionals() -> [ParsedDevotional] {
    guard let devotionals = loadCachedDevotionals() else { return [] }
    return devotionals
        .sorted { $0.date < $1.date }
        .map { DevotionalParser.buildParsedDevotional(from: $0) }
}
```

ISO-8601 `yyyy-MM-dd` strings sort lexicographically = chronologically, so string comparison is correct.

---

## Step 3: `Acts2votion/DevotionalViewModel.swift` — Multi-devotional state

**Replace `ViewState` and the load method:**

```swift
enum ViewState {
    case loading
    case loaded([ParsedDevotional])
    case empty
}

@Observable @MainActor
final class DevotionalViewModel {
    var viewState: ViewState = .loading
    var selectedDateID: String = ""

    func loadDevotionals() async {
        viewState = .loading
        await DevotionalStore.shared.fetchIfNeeded()

        let allDevotionals = DevotionalStore.shared.allCachedDevotionals()
        guard !allDevotionals.isEmpty else {
            viewState = .empty
            return
        }

        let todaysDateID = DevotionalStore.shared.todaysDevotional()?.date ?? allDevotionals.last!.date
        selectedDateID = todaysDateID
        viewState = .loaded(allDevotionals)
    }
}
```

- `selectedDateID` is a `String` bound to `TabView(selection:)`. SwiftUI updates it as the user swipes.
- Initial selection uses `todaysDevotional()?.date` so the app opens on the same entry it does today.

---

## Step 4: `Acts2votion/DevotionalView.swift` — TabView paging

### 4a. Replace the `.loaded` case with a `TabView`:

```swift
case .loaded(let devotionals):
    TabView(selection: $viewModel.selectedDateID) {
        ForEach(devotionals) { devotional in
            devotionalPage(devotional)
                .tag(devotional.date)
        }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
```

### 4b. Extract existing ScrollView body into a `devotionalPage(_:)` method:

```swift
private func devotionalPage(_ devotional: ParsedDevotional) -> some View {
    ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 0) {
            dateLabel(for: devotional.date)
                .padding(.bottom, 16)
            // ... same verse title, divider, content body as current code
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}
```

### 4c. Replace `todaysDateLabel` with a parameterized `dateLabel(for:)`:

```swift
private func dateLabel(for dateString: String) -> some View {
    Text(formattedDate(dateString))
        .font(.custom("Georgia", size: 12))
        .fontWeight(.regular)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .kerning(0.8)
}

private func formattedDate(_ isoDateString: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate]
    guard let date = formatter.date(from: isoDateString) else { return isoDateString }
    let displayFormatter = DateFormatter()
    displayFormatter.dateFormat = "MMMM d, yyyy"
    return displayFormatter.string(from: date)
}
```

### 4d. Update `.task` call:

```swift
.task {
    await viewModel.loadDevotionals()
}
```

### 4e. All other methods unchanged:
`memoryVerseBody`, `discussionSections`, `sectionView`, `bulletPointRow`, `isMemoryVerse` — no modifications needed.

---

## Files NOT Modified
- `ContentView.swift` — thin wrapper, no changes
- `DevotionalParser.swift` — parsing logic unchanged
- `Act2votionWidget/` — widget uses `todaysDevotional()` which is unchanged
- `Acts2votionTests/` — existing tests still pass (optional: add test for `allCachedDevotionals()`)

---

## Verification
1. Build the project in Xcode — confirm no compiler errors
2. Launch app — should open on today's devotional (or nearest lookback)
3. Swipe left — previous day's devotional appears with correct date header
4. Swipe right — next day's devotional appears with correct date header
5. Swipe to first/last cached entry — bounce effect at the edge, no crash
6. Verify memory verse type pages display correctly (centered italic)
7. Verify bible_text type pages display correctly (subheadings + bullets)
8. Verify vertical scrolling still works within each page (no gesture conflict)
9. Run existing tests — `DevotionalStoreTests` should still pass
