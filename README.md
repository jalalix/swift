# JalaliX - Swift

Jalali (Persian / Shamsi) calendar for Swift. Pure Swift / Foundation - IANA zones via `TimeZone`.

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

```swift
import JalaliX

let date = try JalaliX.create(isoDate: "2025-02-25")

date.format("YYYY/MM/DD") // 1403/12/07
date.format("DD MMM YYYY", persianDigits: true) // ۰۷ اسفند ۱۴۰۳

try JalaliX.parseJalali("1403/12/07").toISODate() // 2025-02-25
```

`toISODate()` uses wall-clock getters in the active timezone.

## Requirements

- Swift 5.9+
- macOS 13+, iOS 16+, tvOS 16+, watchOS 9+

## Install

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/jalalix/swift.git", from: "0.1.0")
]
```

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

**File → Add Package Dependencies…** → `https://github.com/jalalix/swift.git` → **Up to Next Major** from `0.1.0`.

## Usage

### create / format

```swift
let now = try JalaliX.create(unixMs: Int64(Date().timeIntervalSince1970 * 1000), timezone: "Asia/Tehran")

now.format("YYYY/MM/DD")
now.format("WN، DD MMM YYYY")
now.format("YYYY/MM/DD", persianDigits: true)
now.format("DD MMM YYYY", options: ["calendar": "gregorian"])
```

`format` also accepts `calendar: "gregorian"` via the `options` dictionary overload.

### parseJalali

```swift
try JalaliX.parseJalali("1403/12/07")
try JalaliX.parseJalali("۱۴۰۳-۱۲-۰۷ 14:30")
try JalaliX.parseJalali("1403.12.07")
```

Named `parseJalali` because `Date` already has parsing helpers. Accepts `/`, `-`, or `.` as the date separator.

### normalizeQueryDate

Soft-normalize loose API/query date values to a Gregorian `YYYY-MM-DD HH:mm:ss` string (or `nil`). Does not throw on junk input.

```swift
JalaliX.normalizeQueryDate("1403/12/07", options: ["timezone": "Asia/Tehran"])
// "2025-02-25 00:00:00"

JalaliX.normalizeQueryDate("undefined") // nil
JalaliX.normalizeQueryDate(1_740_430_800_000, options: ["timezone": "Asia/Tehran"])
// "2025-02-25 00:30:00"
```

Handles sentinels, unix timestamps (seconds or milliseconds; non-positive → `nil`), Persian/Arabic-Indic digits, `/` `-` `.` separators, fractional seconds, optional `Z` / offset suffixes.

Detects Jalali when the year is in `jalaliYearMin`…`jalaliYearMax` (default `1`…`1899`) **and** the civil date is valid; otherwise Gregorian when valid, or returns the digit-cleaned string. Non-string/non-number values pass through unchanged.

### toISODate

```swift
let d = try JalaliX.create(isoDate: "2025-02-25T00:30:00+03:30")

d.toISODate() // 2025-02-25
d.toISODate("jalali") // 1403-12-07
```

### add / start / end

```swift
try JalaliX.create(isoDate: "2025-02-25").addMonths(1).getStartOfMonth().format("YYYY/MM/DD")
// e.g. 1404/01/01

let d = try JalaliX.create(unixMs: 1_740_430_800_000, timezone: "Asia/Tehran")
d.addDays(7).format("YYYY/MM/DD")
d.getEndOfWeek().format("YYYY/MM/DD")
```

### Persian / Arabic digits

```swift
JalaliX.toPersian("1403/12/07") // ۱۴۰۳/۱۲/۰۷
JalaliX.fromPersian("۱۴۰۳/۱۲/۰۷") // 1403/12/07
JalaliX.fromPersian("١٤٠٣/١٢/٠٧") // 1403/12/07 (Arabic-Indic)
```

## Timezone

Internal storage is always a **UTC Unix millisecond instant** plus an IANA timezone id. `setTimezone` is **instant-preserving**: the timestamp stays the same; only the zone (and therefore wall clock / Jalali day) changes.

```swift
let d = try JalaliX.create(unixMs: 1_740_430_800_000)

let tehran = try d.setTimezone("Asia/Tehran")
tehran.format("YYYY/MM/DD") // 1403/12/07
tehran.format("HH:mm") // 00:30

let utc = try d.setTimezone("UTC")
utc.format("YYYY/MM/DD") // 1403/12/06
utc.format("HH:mm") // 21:00

tehran.getTime() == utc.getTime() // true
```

- **Aliases:** `utc` / `gmt` → `UTC`; `local` / `default` / `system` → host IANA.
- **Invalid zone** → throws `JalaliXError.invalidTimezone`.

```swift
try JalaliX.create(unixMs: Int64(Date().timeIntervalSince1970 * 1000), timezone: "Asia/Tehran")
```

## Months

Easy to get wrong:

- `getMonth()` → **1…12** (Farvardin = 1)
- `setMonth(m)` / `setFullYear(y, m)` → **0…11**, same as `Date` (Farvardin = 0)

```swift
let d = try JalaliX.create(unixMs: Int64(Date().timeIntervalSince1970 * 1000))
try d.setFullYear(1404, 0, 1) // 1 Farvardin 1404
d.getMonth() // 1
```

## Format tokens

| Token               | Meaning                         |
| ------------------- | ------------------------------- |
| `YYYY` `YY`         | year                            |
| `MMM` `MM` `M`      | month name / number             |
| `DD` `D`            | day                             |
| `HH` `hh` `mm` `ss` | time                            |
| `A` `a`             | meridiem (ق.ظ. / ب.ظ. or AM/PM) |
| `WN` `WL`           | weekday name / letter           |
| `w` `DDD`           | week of year / day of year      |
| `X` `x`             | unix seconds / ms               |

## API

Options for `create` / `parseJalali` / `normalizeQueryDate` use `[String: Any]` or `[String: String]` with keys `timezone`, `jalaliYearMin`, `jalaliYearMax`.

### Static

| API                              | Description                                                                                                 |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `persianNumbers`                 | Array of Persian digit characters `۰`…`۹`.                                                                  |
| `arabicNumbers`                  | Array of Arabic-Indic digit characters `٠`…`٩`.                                                             |
| `create(_:options:)`             | Build from unix ms, ISO string, `Date`, or `JalaliX`; optional `timezone` in options.                       |
| `create(unixMs:timezone:)`       | Build from Unix milliseconds with optional timezone.                                                        |
| `create(isoDate:timezone:)`      | Build from Gregorian ISO / date string with optional timezone.                                              |
| `parseJalali(_:options:)`        | Parse a Jalali date/time string (`/` `-` `.`, Persian/Arabic digits, optional time).                        |
| `normalizeQueryDate(_:options:)` | Soft-normalize loose query values → Gregorian `YYYY-MM-DD HH:mm:ss`, cleaned string, passthrough, or `nil`. |
| `isValidDate(_:)`                | `true` if the value is a supported date type (`JalaliX`, `Date`, numeric, etc.).                            |
| `toPersian(_:)`                  | Replace Western digits `0-9` with Persian `۰-۹`.                                                            |
| `fromPersian(_:)`                | Replace Persian `۰-۹` and Arabic-Indic `٠-٩` with Western digits.                                           |
| `compare(_:_:)`                  | `true` if the first date is strictly before the second (by unix ms).                                        |

### Instance - getters

| API                 | Description                                                           |
| ------------------- | --------------------------------------------------------------------- |
| `getFullYear()`     | Jalali year in the active timezone.                                   |
| `getMonth()`        | Jalali month **1…12** (Farvardin = 1).                                |
| `getDate()`         | Jalali day of month **1…31**.                                         |
| `getDay()`          | Weekday **1…7** (Saturday = 1 … Friday = 7).                          |
| `getHours()`        | Wall-clock hours in the active timezone.                              |
| `getMinutes()`      | Wall-clock minutes.                                                   |
| `getSeconds()`      | Wall-clock seconds.                                                   |
| `getMilliseconds()` | Wall-clock milliseconds.                                              |
| `getTime()`         | Unix timestamp in milliseconds (UTC instant).                         |
| `getTimezone()`     | Active IANA timezone id.                                              |
| `getWeekOfYear()`   | Jalali week-of-year (1-based).                                        |
| `getDayOfYear()`    | Day of Jalali year (1…365/366).                                       |
| `getDayISO()`       | ISO-style weekday index used internally for week math.                |
| `getHoursISO()`     | Hours in 0…23 for formatting helpers.                                 |
| `getMeridiem()`     | Localized meridiem string (ق.ظ./ب.ظ. or AM/PM depending on calendar). |

### Instance - setters

| API                   | Description                                              |
| --------------------- | -------------------------------------------------------- |
| `setTime(_:)`         | Set the UTC instant from unix milliseconds.              |
| `setMilliseconds(_:)` | Set milliseconds (wall clock).                           |
| `setSeconds(_:_:)`    | Set seconds and optional milliseconds.                   |
| `setMinutes(_:_:_:)`  | Set minutes and optional lower units.                    |
| `setHours(_:_:_:_:)`  | Set hours and optional lower units.                      |
| `setDate(_:)`         | Set Jalali day of month.                                 |
| `setMonth(_:_:)`      | Set Jalali month **0…11** (Farvardin = 0); optional day. |
| `setFullYear(_:_:_:)` | Set Jalali year; optional month **0…11** and day.        |
| `setTimezone(_:)`     | Instant-preserving zone change; returns a new instance.  |

### Instance - math, range, format

| API                                 | Description                                                     |
| ----------------------------------- | --------------------------------------------------------------- |
| `addYears(_:)`                      | Add calendar years (mutates / returns `self`).                  |
| `addMonths(_:)`                     | Add calendar months.                                            |
| `addWeeks(_:)`                      | Add weeks.                                                      |
| `addDays(_:)`                       | Add days.                                                       |
| `getStartOfYear()`                  | Start of Jalali year (mutates / returns `self`).                |
| `getStartOfMonth()`                 | Start of Jalali month.                                          |
| `getStartOfWeek()`                  | Start of week.                                                  |
| `getStartOfDay()`                   | Start of day (`00:00:00.000`).                                  |
| `getEndOfYear()`                    | End of Jalali year.                                             |
| `getEndOfMonth()`                   | End of Jalali month.                                            |
| `getEndOfWeek()`                    | End of week.                                                    |
| `getEndOfDay()`                     | End of day (`23:59:59.999`).                                    |
| `format(_:persianDigits:calendar:)` | Format with tokens; optional Persian digits and `calendar`.     |
| `format(_:options:)`                | Format with `persianDigits` / `calendar` in options dictionary. |
| `toISODate(_:)`                     | `YYYY-MM-DD` in `"gregorian"` (default) or `"jalali"`.          |
| `clone()`                           | Copy with the same instant and timezone.                        |
| `toString()`                        | Human-readable Jalali date/time string.                         |
| `toDateString()`                    | Jalali weekday + date string.                                   |
| `toLocaleDateString()`              | `YYYY/MM/DD` in Jalali.                                         |
| `toLocaleTimeString()`              | 12-hour time with meridiem.                                     |
| `description`                       | Same as `toString()` for `CustomStringConvertible`.             |

## Test

```bash
swift test
```

## Links

- https://jalalix.com
- https://github.com/jalalix/swift
- [CHANGELOG.md](./CHANGELOG.md)

## License

MIT
