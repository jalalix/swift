# JalaliX

Jalali (Persian / Shamsi) calendar for Swift. Pure Swift / Foundation — IANA zones via `TimeZone`.

```swift
import JalaliX

let date = try JalaliX.create(isoDate: "2025-02-25")

date.format("YYYY/MM/DD")  // 1403/12/07
date.format("DD MMM YYYY", persianDigits: true)  // ۰۷ اسفند ۱۴۰۳

try JalaliX.parseJalali("1403/12/07").toISODate()  // 2025-02-25
```

## Requirements

- Swift 5.9+
- macOS 13+, iOS 16+, tvOS 16+, watchOS 9+

## Install

### Swift Package Manager

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jalalix/swift.git", from: "0.1.0")
]
```

Then add the product to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "JalaliX", package: "swift")
    ]
)
```

```swift
import JalaliX
```

### Xcode

**File → Add Package Dependencies…** → paste `https://github.com/jalalix/swift.git` → version **Up to Next Major** from `0.1.0`.

## Months

- `getMonth()` -> 1..12 (Farvardin = 1)
- `setMonth(m)` / `setFullYear(y, m)` -> 0..11, same as JS `Date` (Farvardin = 0)

## Timezone

Internal storage is a **UTC Unix millisecond instant** plus an IANA timezone id. `setTimezone` is **instant-preserving**.

```swift
let d = try JalaliX.create(unixMs: 1_740_430_800_000)
let tehran = try d.setTimezone("Asia/Tehran")
tehran.format("YYYY/MM/DD")  // 1403/12/07
tehran.format("HH:mm:ss")    // 00:30:00
```

- **Aliases:** `utc` / `gmt` -> `UTC`; `local` / `default` / `system` -> host IANA.
- **Invalid zone** -> throws `JalaliXError.invalidTimezone`.

## Test

```bash
swift test
```

## License

MIT
