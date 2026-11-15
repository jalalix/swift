import Foundation

// Jalali (Persian / Shamsi) calendar. Pure Swift port of @jalalix/typescript.
// Instant-preserving IANA timezones via `TimeZone`.
public final class JalaliX {
	public static let persianNumbers = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	public static let arabicNumbers = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]

	private struct WallParts {
		var year: Int
		var month: Int
		var day: Int
		var hour: Int
		var minute: Int
		var second: Int
		var ms: Int
	}

	private struct JalaliDate {
		var year: Int = 1348
		var month: Int = 10
		var day: Int = 11
		var hours: Int = 0
		var min: Int = 0
		var sec: Int = 0
		var ms: Int = 0
		var isLeapYear: Bool = false
	}

	private var ms: Int64
	private var timezoneId: String
	private var jalali = JalaliDate()
	private var isConverted = false
	private let leapYearDivision = 0.24219858156
	private let firstDayOfWeek = 6
	private let dateLength: Int64 = 86_400_000
	private let weekDaysNames = ["شنبه", "یکشنبه", "دوشنبه", "سه شنبه", "چهار شنبه", "پنج شنبه", "جمعه"]
	private let weekDaysLetters = ["ش", "ی", "د", "س", "چ", "پ", "ج"]
	private let weekDaysGregorianNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	private let weekDaysGregorianLetters = ["S", "M", "T", "W", "T", "F", "S"]
	private let monthsNames = ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]
	private let monthsGregorianNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	private let am = "ق.ظ."
	private let pm = "ب.ظ."
	private let amGregorian = "AM"
	private let pmGregorian = "PM"

	public init(_ milliseconds: Int64? = nil) {
		if let milliseconds {
			self.ms = milliseconds
		} else {
			self.ms = Int64(Date().timeIntervalSince1970 * 1000)
		}

		self.timezoneId = "UTC"
	}

	private static func hostTimezone() -> String {
		TimeZone.current.identifier
	}

	private func timeZone() -> TimeZone {
		if timezoneId.uppercased() == "UTC" || timezoneId == "Etc/UTC" {
			return TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
		}

		guard let tz = TimeZone(identifier: timezoneId) else {
			fatalError("Invalid IANA timezone: \(timezoneId)")
		}

		return tz
	}

	private func getWallParts() -> WallParts {
		let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = timeZone()
		let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
		let milli = Int(((ms % 1000) + 1000) % 1000)

		return WallParts(
			year: c.year ?? 1970,
			month: c.month ?? 1,
			day: c.day ?? 1,
			hour: c.hour ?? 0,
			minute: c.minute ?? 0,
			second: c.second ?? 0,
			ms: milli
		)
	}

	private func wallToUtc(y: Int, m: Int, d: Int, h: Int, mi: Int, s: Int, msVal: Int) -> Int64 {
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(secondsFromGMT: 0)!
		let comps = DateComponents(year: y, month: m, day: d, hour: h, minute: mi, second: s)
		let wantDate = cal.date(from: comps) ?? Date(timeIntervalSince1970: 0)
		let want = Int64(wantDate.timeIntervalSince1970 * 1000)
		var utc = want
		let tz = timeZone()

		for _ in 0..<14 {
			let probe = Date(timeIntervalSince1970: Double(utc) / 1000.0)
			var wallCal = Calendar(identifier: .gregorian)
			wallCal.timeZone = tz
			let p = wallCal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: probe)
			let gotComps = DateComponents(year: p.year, month: p.month, day: p.day, hour: p.hour, minute: p.minute, second: p.second)
			let gotDate = cal.date(from: gotComps) ?? Date(timeIntervalSince1970: 0)
			let got = Int64(gotDate.timeIntervalSince1970 * 1000)
			let diff = want - got
			if diff == 0 { break }
			utc += diff
		}

		let normalizedMs = ((msVal % 1000) + 1000) % 1000

		return (utc / 1000) * 1000 + Int64(normalizedMs)
	}

	@discardableResult
	private func toJalali() -> JalaliDate {
		if !isConverted {
			let wall = getWallParts()
			var cal = Calendar(identifier: .gregorian)
			cal.timeZone = TimeZone(secondsFromGMT: 0)!
			let civil = cal.date(from: DateComponents(year: wall.year, month: wall.month, day: wall.day))!
			let base = cal.date(from: DateComponents(year: 1970, month: 1, day: 1))!
			let diffDays = Int(civil.timeIntervalSince(base) / 86_400)

			jalali.year = 1348
			jalali.month = 10
			jalali.day = 11

			if diffDays > 0 {
				for _ in 0..<diffDays {
					jalali.day += 1

					if jalali.month < 7 && jalali.day > 31 {
						jalali.month += 1; jalali.day = 1
					} else if jalali.month > 6 && jalali.month < 12 && jalali.day > 30 {
						jalali.month += 1; jalali.day = 1
					} else if jalali.month == 12 {
						let leap = checkLeapYear(jalali.year)

						if leap && jalali.day > 30 {
							jalali.year += 1; jalali.month = 1; jalali.day = 1
						} else if !leap && jalali.day > 29 {
							jalali.year += 1; jalali.month = 1; jalali.day = 1
						}
					}
				}
			} else if diffDays < 0 {
				for _ in 0..<(-diffDays) {
					jalali.day -= 1

					if jalali.day < 1 {
						if jalali.month == 1 {
							jalali.year -= 1; jalali.month = 12
							jalali.day = checkLeapYear(jalali.year) ? 30 : 29
						} else if jalali.month < 8 {
							jalali.month -= 1; jalali.day = 31
						} else if jalali.month < 13 {
							jalali.month -= 1; jalali.day = 30
						}
					}
				}
			}

			jalali.hours = wall.hour
			jalali.min = wall.minute
			jalali.sec = wall.second
			jalali.ms = wall.ms
			jalali.isLeapYear = checkLeapYear(jalali.year)
			isConverted = true
		}

		let wall = getWallParts()
		jalali.hours = wall.hour
		jalali.min = wall.minute
		jalali.sec = wall.second
		jalali.ms = wall.ms

		return jalali
	}

	private func toGregorian(year: Int, month: Int, day: Int, hours: Int, min: Int, sec: Int, msVal: Int) -> Int64 {
		var jy = 1348, jm = 10, jd = 11
		var diffDays = 0
		let after = year > 1348 || (year == 1348 && month >= 10) || (year == 1348 && month == 10 && day >= 11)
		let before = year < 1348 || (year == 1348 && month < 10) || (year == 1348 && month == 10 && day < 11)

		if after {
			while !(jy == year && jm == month && jd == day) {
				diffDays += 1
				jd += 1

				if jm < 7 && jd > 31 { jm += 1; jd = 1 }
				else if jm > 6 && jm < 12 && jd > 30 { jm += 1; jd = 1 }
				else if jm == 12 {
					let leap = checkLeapYear(jy)
					if leap && jd > 30 { jy += 1; jm = 1; jd = 1 }
					else if !leap && jd > 29 { jy += 1; jm = 1; jd = 1 }
				}
			}
		} else if before {
			while !(jy == year && jm == month && jd == day) {
				diffDays -= 1
				jd -= 1

				if jd < 1 {
					if jm == 1 {
						jy -= 1; jm = 12
						jd = checkLeapYear(jy) ? 30 : 29
					} else if jm < 8 { jm -= 1; jd = 31 }
					else if jm < 13 { jm -= 1; jd = 30 }
				}
			}
		}

		let wallAsUtc = Int64(diffDays) * dateLength + Int64(hours * 3600 + min * 60 + sec) * 1000 + Int64(msVal)
		let civil = Date(timeIntervalSince1970: Double(wallAsUtc) / 1000.0)
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(secondsFromGMT: 0)!
		let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: civil)
		let milli = (c.nanosecond ?? 0) / 1_000_000

		return wallToUtc(y: c.year ?? 1970, m: c.month ?? 1, d: c.day ?? 1, h: c.hour ?? 0, mi: c.minute ?? 0, s: c.second ?? 0, msVal: milli)
	}

	private func checkLeapYear(_ year: Int) -> Bool {
		guard year > 0 else { return false }
		let checkYear = Double(year + 2346) * leapYearDivision

		return checkYear - Double(Int(checkYear)) < leapYearDivision
	}

	@discardableResult
	private func reset() -> JalaliDate {
		isConverted = false
		jalali.year = 1348; jalali.month = 10; jalali.day = 11

		return toJalali()
	}

	private func addZero(_ number: Int) -> String {
		number > -1 && number < 10 ? "0\(number)" : "\(number)"
	}

	private func getWallWeekday() -> Int {
		let wall = getWallParts()
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(secondsFromGMT: 0)!
		let date = cal.date(from: DateComponents(year: wall.year, month: wall.month, day: wall.day))!
		// Sunday=1 in Calendar; convert to JS 0=Sunday

		return cal.component(.weekday, from: date) - 1
	}

	private func normalizeDate(_ days: Int) -> Int64 {
		setTime(ms + Int64(days) * dateLength)

		return getTime()
	}

	private func normalizeJalali(year: Int, month: Int, day: Int) -> Int64 {
		var y = year, m = month, d = day
		if m < 1 {
			let yearDiff = Int(ceil(Double(1 - m) / 12.0))
			y -= yearDiff
			m = 12 * yearDiff + m
		} else if m > 12 {
			let yearDiff = Int(floor(Double(m - 1) / 12.0))
			y += yearDiff
			m = m - 12 * yearDiff
		}

		if m > 6 && m < 12 && d > 30 { d = 30 }
		else if m == 12 {
			let leap = checkLeapYear(y)
			if leap && d > 30 { d = 30 }
			else if !leap && d > 29 { d = 29 }
		}

		let wall = getWallParts()

		return setTime(toGregorian(year: y, month: m, day: d, hours: wall.hour, min: wall.minute, sec: wall.second, msVal: wall.ms))
	}

	private func normalizeTimezone(_ timezone: String?) throws -> String {
		guard let timezone else { return timezoneId }
		let trimmed = timezone.trimmingCharacters(in: .whitespacesAndNewlines)

		if trimmed.isEmpty { throw JalaliXError.invalidTimezone(trimmed) }
		let lowered = trimmed.lowercased()

		if ["default", "local", "system"].contains(lowered) { return Self.hostTimezone() }
		if ["utc", "gmt"].contains(lowered) { return "UTC" }

		guard TimeZone(identifier: trimmed) != nil || trimmed.uppercased() == "UTC" else {
			throw JalaliXError.invalidTimezone(trimmed)
		}

		if let resolved = TimeZone(identifier: trimmed)?.identifier {
			return resolved
		}

		return trimmed
	}

	public func toString() -> String {
		let j = toJalali()

		return "\(weekDayName()) \(addZero(j.day)) \(monthsNames[j.month - 1]) \(addZero(j.year)) \(j.hours):\(addZero(j.min)):\(addZero(j.sec))\(utcTimezoneString())"
	}

	public func toDateString() -> String {
		let j = toJalali()

		return "\(weekDayName()) \(addZero(j.day)) \(monthsNames[j.month - 1]) \(addZero(j.year))"
	}

	public func toLocaleDateString() -> String {
		let j = toJalali()

		return "\(addZero(j.year))/\(addZero(j.month))/\(addZero(j.day))"
	}

	public func toLocaleTimeString() -> String {
		let j = toJalali()

		return "\(j.hours % 12):\(addZero(j.min)):\(addZero(j.sec)) \(getMeridiem())"
	}

	public func getFullYear() -> Int { toJalali().year }
	public func getMonth() -> Int { toJalali().month }
	public func getDate() -> Int { toJalali().day }
	public func getDay() -> Int { (getWallWeekday() - firstDayOfWeek + 7 + 1) % 7 }
	public func getHours() -> Int { getWallParts().hour }
	public func getMinutes() -> Int { getWallParts().minute }
	public func getSeconds() -> Int { getWallParts().second }
	public func getMilliseconds() -> Int { Int(((ms % 1000) + 1000) % 1000) }
	public func getTime() -> Int64 { ms }

	@discardableResult
	public func setTime(_ time: Int64) -> Int64 {
		ms = time
		reset()
		return getTime()
	}

	@discardableResult
	public func setMilliseconds(_ msVal: Int) -> Int64 {
		let wall = getWallParts()

		return setTime(wallToUtc(y: wall.year, m: wall.month, d: wall.day, h: wall.hour, mi: wall.minute, s: wall.second, msVal: msVal))
	}

	@discardableResult
	public func setSeconds(_ sec: Int, _ msVal: Int? = nil) -> Int64 {
		let wall = getWallParts()

		return setTime(wallToUtc(y: wall.year, m: wall.month, d: wall.day, h: wall.hour, mi: wall.minute, s: sec, msVal: msVal ?? wall.ms))
	}

	@discardableResult
	public func setMinutes(_ min: Int, _ sec: Int? = nil, _ msVal: Int? = nil) -> Int64 {
		let wall = getWallParts()

		return setTime(wallToUtc(y: wall.year, m: wall.month, d: wall.day, h: wall.hour, mi: min, s: sec ?? wall.second, msVal: msVal ?? wall.ms))
	}

	@discardableResult
	public func setHours(_ hours: Int, _ min: Int? = nil, _ sec: Int? = nil, _ msVal: Int? = nil) -> Int64 {
		let wall = getWallParts()

		return setTime(wallToUtc(y: wall.year, m: wall.month, d: wall.day, h: hours, mi: min ?? wall.minute, s: sec ?? wall.second, msVal: msVal ?? wall.ms))
	}

	@discardableResult
	public func setDate(_ date: Int) -> Int64 {
		let j = toJalali()
		_ = normalizeDate(date - j.day)

		return getTime()
	}

	@discardableResult
	public func setMonth(_ month: Int, _ date: Int? = nil) -> Int64 {
		let j = toJalali()
		_ = normalizeJalali(year: j.year, month: month + 1, day: j.day)
		reset()

		if let date {
			let j2 = toJalali()
			_ = normalizeDate(date - j2.day)
			reset()
		}

		return getTime()
	}

	@discardableResult
	public func setFullYear(_ year: Int, _ month: Int? = nil, _ date: Int? = nil) -> Int64 {
		let j = toJalali()
		_ = normalizeJalali(year: year, month: month.map { $0 + 1 } ?? j.month, day: j.day)
		reset()

		if let date {
			let j2 = toJalali()
			_ = normalizeDate(date - j2.day)
			reset()
		}

		return getTime()
	}

	public static func create(_ date: Any, options: [String: String]? = nil) throws -> JalaliX {
		let output = JalaliX(try parseInput(date))

		if let tz = options?["timezone"] {
			return try output.setTimezone(tz)
		}

		return output
	}

	public static func create(unixMs: Int64, timezone: String? = nil) throws -> JalaliX {
		let output = JalaliX(unixMs)

		if let timezone { return try output.setTimezone(timezone) }
		return output
	}

	public static func create(isoDate: String, timezone: String? = nil) throws -> JalaliX {
		let output = JalaliX(try parseIsoString(isoDate))

		if let timezone { return try output.setTimezone(timezone) }
		return output
	}

	private static func parseInput(_ value: Any) throws -> Int64 {
		switch value {
			case let v as JalaliX: return v.getTime()
			case let v as Int64: return v
			case let v as Int: return Int64(v)
			case let v as Double: return Int64(v)
			case let v as Date: return Int64(v.timeIntervalSince1970 * 1000)
			case let v as String: return try parseIsoString(v)
			default: throw JalaliXError.invalidDate("unsupported type")
		}
	}

	private static func parseIsoString(_ value: String) throws -> Int64 {
		let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
		let dateOnly = try NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)

		if dateOnly.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil {
			let parts = s.split(separator: "-").compactMap { Int($0) }
			var cal = Calendar(identifier: .gregorian)
			cal.timeZone = TimeZone(secondsFromGMT: 0)!
			let date = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
			return Int64(date.timeIntervalSince1970 * 1000)
		}

		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

		if let d = formatter.date(from: s) { return Int64(d.timeIntervalSince1970 * 1000) }

		formatter.formatOptions = [.withInternetDateTime]

		if let d = formatter.date(from: s) { return Int64(d.timeIntervalSince1970 * 1000) }

		throw JalaliXError.invalidDate(value)
	}

	public static func parseJalali(_ value: String, options: [String: String]? = nil) throws -> JalaliX {
		let normalized = fromPersian(value).trimmingCharacters(in: .whitespacesAndNewlines)
		let pattern = #"^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$"#
		let re = try NSRegularExpression(pattern: pattern)

		guard let match = re.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) else {
			throw JalaliXError.invalidJalali(value)
		}

		func group(_ i: Int) -> String? {
			let r = match.range(at: i)
			guard r.location != NSNotFound, let range = Range(r, in: normalized) else { return nil }
			return String(normalized[range])
		}

		let year = Int(group(1)!)!
		let month = Int(group(2)!)!
		let day = Int(group(3)!)!
		let hours = Int(group(4) ?? "0")!
		let minutes = Int(group(5) ?? "0")!
		let seconds = Int(group(6) ?? "0")!

		if month < 1 || month > 12 || day < 1 || day > 31 { throw JalaliXError.invalidJalali(value) }

		let output = try create(Date(), options: options)
		_ = output.setFullYear(year, month - 1, day)
		_ = output.setHours(hours, minutes, seconds, 0)

		return output
	}

	public static func isValidDate(_ date: Any?) -> Bool {
		date is JalaliX || date is Date
	}

	public static func toPersian(_ str: String) -> String {
		var out = str

		for i in 0...9 {
			out = out.replacingOccurrences(of: "\(i)", with: persianNumbers[i])
		}

		return out
	}

	public static func fromPersian(_ str: String) -> String {
		var out = str

		for i in 0...9 {
			out = out.replacingOccurrences(of: persianNumbers[i], with: "\(i)")
			out = out.replacingOccurrences(of: arabicNumbers[i], with: "\(i)")
		}

		return out
	}

	private static let queryDatePattern = try! NSRegularExpression(
		pattern: #"^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?(?:Z|[+-]\d{2}:?\d{2})?)?"#
	)
	private static let fracSecondsPattern = try! NSRegularExpression(pattern: #"(\d{2}:\d{2}:\d{2})\.\d+"#)
	private static let numericStringPattern = try! NSRegularExpression(pattern: #"^[+-]?\d+(\.\d+)?$"#)

	private static func isValidJalaliCivilDate(year: Int, month: Int, day: Int) -> Bool {
		if year < 1 || month < 1 || month > 12 || day < 1 { return false }
		if month <= 6 { return day <= 31 }
		if month <= 11 { return day <= 30 }
		let checkYear = Double(year + 2346) * 0.24219858156
		let isLeap = checkYear - floor(checkYear) < 0.24219858156
		return day <= (isLeap ? 30 : 29)
	}

	private static func isValidGregorianDate(year: Int, month: Int, day: Int) -> Bool {
		if month < 1 || month > 12 || day < 1 { return false }
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(secondsFromGMT: 0)!
		var comps = DateComponents()
		comps.year = year
		comps.month = month
		comps.day = day
		guard let date = cal.date(from: comps) else { return false }
		let parts = cal.dateComponents([.year, .month, .day], from: date)
		return parts.year == year && parts.month == month && parts.day == day
	}

	private static func normalizeQueryTimestamp(_ timestamp: Int64, options: [String: Any]?) -> String? {
		var ts = timestamp
		if ts > 9_999_999_999 { ts /= 1000 }
		if ts <= 0 { return nil }
		var createOpts: [String: String]?
		if let tz = options?["timezone"] as? String { createOpts = ["timezone": tz] }
		return try? create(ts * 1000, options: createOpts).format(
			"YYYY-MM-DD HH:mm:ss",
			options: ["calendar": "gregorian"]
		)
	}

	/// Soft-normalizes loose query / form date inputs into a Gregorian `YYYY-MM-DD HH:mm:ss` string (or `nil`).
	public static func normalizeQueryDate(_ value: Any?, options: [String: Any]? = nil) -> Any? {
		if value == nil { return nil }

		if let s = value as? String {
			if s == "null" || s.isEmpty || s == "undefined"
				|| s.lowercased() == "invalid date"
				|| s.range(of: "NaN", options: .caseInsensitive) != nil {
				return nil
			}
		}

		if let n = value as? Int { return normalizeQueryTimestamp(Int64(n), options: options) }
		if let n = value as? Int64 { return normalizeQueryTimestamp(n, options: options) }
		if let n = value as? Double {
			if n.isNaN { return nil }
			return normalizeQueryTimestamp(Int64(n), options: options)
		}

		guard let value = value as? String else { return value }

		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedRange = NSRange(trimmed.startIndex..., in: trimmed)
		if !trimmed.isEmpty,
		   numericStringPattern.firstMatch(in: trimmed, range: trimmedRange) != nil,
		   let num = Double(trimmed) {
			return normalizeQueryTimestamp(Int64(num), options: options)
		}

		var digits = fromPersian(value)
		let digitsNs = digits as NSString
		digits = fracSecondsPattern.stringByReplacingMatches(
			in: digits,
			range: NSRange(location: 0, length: digitsNs.length),
			withTemplate: "$1"
		)

		let matchRange = NSRange(digits.startIndex..., in: digits)
		guard let match = queryDatePattern.firstMatch(in: digits, range: matchRange),
			  match.range.location == 0 else {
			return digits
		}

		func group(_ i: Int) -> String? {
			let r = match.range(at: i)
			guard r.location != NSNotFound, let range = Range(r, in: digits) else { return nil }
			return String(digits[range])
		}

		let year = Int(group(1)!)!
		let month = Int(group(2)!)!
		let day = Int(group(3)!)!
		let hour = Int(group(4) ?? "0")!
		let minute = Int(group(5) ?? "0")!
		let second = Int(group(6) ?? "0")!

		let jalaliYearMin = (options?["jalaliYearMin"] as? Int).flatMap { $0 != 0 ? $0 : nil } ?? 1
		let jalaliYearMax = (options?["jalaliYearMax"] as? Int).flatMap { $0 != 0 ? $0 : nil } ?? 1899

		if year >= jalaliYearMin && year <= jalaliYearMax && isValidJalaliCivilDate(year: year, month: month, day: day) {
			let jalaliStr = String(format: "%04d/%02d/%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
			var parseOpts: [String: String]?
			if let tz = options?["timezone"] as? String { parseOpts = ["timezone": tz] }
			if let parsed = try? parseJalali(jalaliStr, options: parseOpts) {
				return parsed.format("YYYY-MM-DD HH:mm:ss", options: ["calendar": "gregorian"])
			}
		}

		if isValidGregorianDate(year: year, month: month, day: day) {
			return String(format: "%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
		}

		return digits
	}

	public static func compare(_ date: JalaliX, _ comparing: JalaliX) -> Bool {
		date.getTime() < comparing.getTime()
	}

	public func clone() -> JalaliX {
		let output = JalaliX(ms)
		output.timezoneId = timezoneId

		return output
	}

	public func getTimezone() -> String { timezoneId }

	public func getWeekOfYear() -> Int {
		let dayOfYear = getDayOfYear()
		let start = clone().getStartOfYear()
		let dayOfWeek = start.getDayISO()

		return Int(ceil(Double(dayOfYear + dayOfWeek - 1) / 7.0))
	}

	public func getDayOfYear() -> Int {
		let j = toJalali()

		if j.month < 7 { return j.day + (j.month - 1) * 31 }
		if j.month < 12 { return j.day + 186 + (j.month - 7) * 30 }

		return j.day + 336
	}

	public func getDayISO() -> Int { ((getDay() + 6) % 7) + 1 }

	public func getHoursISO() -> Int {
		let hours = getHours()

		return hours > 12 ? hours - 12 : hours
	}

	public func getMeridiem() -> String {
		toJalali().hours > 12 ? pm : am
	}

	@discardableResult
	public func getStartOfYear() -> JalaliX {
		addDays(-1 * getDayOfYear() + 1).getStartOfDay()
	}

	@discardableResult
	public func getStartOfMonth() -> JalaliX {
		addDays(-1 * getDate() + 1).getStartOfDay()
	}

	@discardableResult
	public func getStartOfWeek() -> JalaliX {
		addDays(-1 * getDayISO() + 1).getStartOfDay()
	}

	@discardableResult
	public func getStartOfDay() -> JalaliX {
		_ = setHours(0, 0, 0, 0)

		return self
	}

	@discardableResult
	public func getEndOfYear() -> JalaliX {
		let last = toJalali().isLeapYear ? 366 : 365

		return addDays(last - getDayOfYear()).getEndOfDay()
	}

	@discardableResult
	public func getEndOfMonth() -> JalaliX {
		let j = toJalali()
		var last = 31

		if j.month > 6 && j.month < 12 { last = 30 }
		else if j.month == 12 { last = j.isLeapYear ? 30 : 29 }

		return addDays(last - getDate()).getEndOfDay()
	}

	@discardableResult
	public func getEndOfWeek() -> JalaliX {
		addDays(7 - getDayISO()).getEndOfDay()
	}

	@discardableResult
	public func getEndOfDay() -> JalaliX {
		_ = setHours(23, 59, 59, 999)

		return self
	}

	public func setTimezone(_ timezone: String?) throws -> JalaliX {
		let output = JalaliX(ms)
		output.timezoneId = try normalizeTimezone(timezone)

		return output
	}

	@discardableResult
	public func addYears(_ year: Int) -> JalaliX {
		let j = toJalali()
		_ = normalizeJalali(year: j.year + year, month: j.month, day: j.day)
		reset()

		return self
	}

	@discardableResult
	public func addMonths(_ month: Int) -> JalaliX {
		let j = toJalali()
		_ = normalizeJalali(year: j.year, month: j.month + month, day: j.day)
		reset()

		return self
	}

	@discardableResult
	public func addWeeks(_ weeks: Int) -> JalaliX {
		_ = normalizeDate(weeks * 7)
		reset()

		return self
	}

	@discardableResult
	public func addDays(_ days: Int) -> JalaliX {
		_ = normalizeDate(days)
		reset()

		return self
	}

	public func toISODate(_ calendar: String = "gregorian") -> String {
		if calendar == "jalali" { return format("YYYY-MM-DD") }
		let wall = getWallParts()

		return "\(wall.year)-\(addZero(wall.month))-\(addZero(wall.day))"
	}

	public func format(_ str: String, persianDigits: Bool = false, calendar: String? = nil) -> String {
		var opts: [String: Any] = ["persianDigits": persianDigits]
		if let calendar { opts["calendar"] = calendar }

		return format(str, options: opts)
	}

	public func format(_ str: String, options: [String: Any]?) -> String {
		let persian = (options?["persianDigits"] as? Bool) ?? false
		let useGregorian = (options?["calendar"] as? String) == "gregorian"
		var placeholders: [String] = []

		func ph(_ val: String) -> String {
			let i = placeholders.count
			placeholders.append(val)
			return "\u{E000}\(i)\u{E001}"
		}

		var output = str
		let wall = getWallParts()
		let year = useGregorian ? wall.year : getFullYear()
		let month = useGregorian ? wall.month : getMonth()
		let weekOfYear = useGregorian ? gregorianWeekOfYear() : getWeekOfYear()
		let dayOfYear = useGregorian ? gregorianDayOfYear() : getDayOfYear()
		let date = useGregorian ? wall.day : getDate()
		let monthName = useGregorian ? monthsGregorianNames[month - 1] : monthsNames[month - 1]
		let weekDayNameVal = useGregorian ? weekDaysGregorianNames[getWallWeekday()] : weekDayName()
		let weekDayLetter = useGregorian ? weekDaysGregorianLetters[getWallWeekday()] : weekDaysLetters[(getDay() + firstDayOfWeek) % 7]
		let meridiem = useGregorian ? (getHours() >= 12 ? pmGregorian : amGregorian) : getMeridiem()
		let yearStr = "\(year)"

		let replacements: [(String, String)] = [
			("YYYY", yearStr), ("YYY", String(yearStr.suffix(3))), ("YY", String(yearStr.suffix(2))), ("Y", String(yearStr.suffix(1))),
			("MMM", monthName), ("MM", addZero(month)), ("M", "\(month)"),
			("W", addZero(weekOfYear)), ("w", "\(weekOfYear)"),
			("DW", "\(getDayISO())"), ("dw", "\(useGregorian ? (getWallWeekday() == 0 ? 7 : getWallWeekday()) : getDay())"),
			("WN", weekDayNameVal), ("wn", weekDayNameVal), ("WL", weekDayLetter), ("wl", weekDayLetter),
			("DDDD", addZero(dayOfYear)), ("DDD", "\(dayOfYear)"),
			("DD", addZero(date)), ("D", "\(date)")
		]

		for (token, val) in replacements {
			if output.contains(token) {
				output = output.replacingOccurrences(of: token, with: ph(val))
			}
		}

		let hours = getHours()

		if output.contains("HH") { output = output.replacingOccurrences(of: "HH", with: ph(addZero(hours))) }
		if output.contains("H") { output = output.replacingOccurrences(of: "H", with: ph("\(hours)")) }

		let hoursISO = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours)

		if output.contains("hh") { output = output.replacingOccurrences(of: "hh", with: ph(addZero(hoursISO))) }
		if output.contains("h") { output = output.replacingOccurrences(of: "h", with: ph("\(hoursISO)")) }
		if output.contains("mm") { output = output.replacingOccurrences(of: "mm", with: ph(addZero(getMinutes()))) }
		if output.contains("m") { output = output.replacingOccurrences(of: "m", with: ph("\(getMinutes())")) }
		if output.contains("ss") { output = output.replacingOccurrences(of: "ss", with: ph(addZero(getSeconds()))) }
		if output.contains("s") { output = output.replacingOccurrences(of: "s", with: ph("\(getSeconds())")) }
		if output.contains("sss") { output = output.replacingOccurrences(of: "sss", with: ph("\(getMilliseconds())")) }
		if output.contains("SSS") { output = output.replacingOccurrences(of: "SSS", with: ph("\(getMilliseconds())")) }
		if output.contains("A") { output = output.replacingOccurrences(of: "A", with: ph(meridiem)) }
		if output.contains("a") { output = output.replacingOccurrences(of: "a", with: ph(meridiem)) }
		if output.contains("X") { output = output.replacingOccurrences(of: "X", with: ph("\(ms / 1000)")) }
		if output.contains("x") { output = output.replacingOccurrences(of: "x", with: ph("\(ms)")) }

		for (i, val) in placeholders.enumerated() {
			output = output.replacingOccurrences(of: "\u{E000}\(i)\u{E001}", with: val)
		}

		return persian ? Self.toPersian(output) : output
	}

	private func weekDayName() -> String {
		weekDaysNames[(getDay() + firstDayOfWeek) % 7]
	}

	private func utcTimezoneString() -> String {
		let wall = getWallParts()
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(secondsFromGMT: 0)!
		let asUtcDate = cal.date(from: DateComponents(year: wall.year, month: wall.month, day: wall.day, hour: wall.hour, minute: wall.minute, second: wall.second))!
		let asUtc = Int64(asUtcDate.timeIntervalSince1970 * 1000) + Int64(wall.ms)
		let offsetMin = Int(((asUtc - ms) / 60_000))
		let sign = offsetMin >= 0 ? "+" : "-"
		let abs = abs(offsetMin)

		return " GMT\(sign)\(addZero(abs / 60))\(addZero(abs % 60))"
	}

	private func gregorianDayOfYear() -> Int {
		let wall = getWallParts()
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(secondsFromGMT: 0)!
		let start = cal.date(from: DateComponents(year: wall.year, month: 1, day: 1))!.addingTimeInterval(-86_400)
		let civil = cal.date(from: DateComponents(year: wall.year, month: wall.month, day: wall.day))!

		return Int(round(civil.timeIntervalSince(start) / 86_400))
	}

	private func gregorianWeekOfYear() -> Int {
		let wall = getWallParts()
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(secondsFromGMT: 0)!
		var d = cal.date(from: DateComponents(year: wall.year, month: wall.month, day: wall.day))!
		var dow = cal.component(.weekday, from: d) - 1 // 0=Sun

		if dow == 0 { dow = 7 }

		d = d.addingTimeInterval(Double(4 - dow) * 86_400)
		let yearStart = cal.date(from: DateComponents(year: cal.component(.year, from: d), month: 1, day: 1))!

		return Int(ceil((d.timeIntervalSince(yearStart) / 86_400 + 1) / 7))
	}
}

public enum JalaliXError: Error, CustomStringConvertible {
	case invalidTimezone(String)
	case invalidDate(String)
	case invalidJalali(String)

	public var description: String {
		switch self {
			case .invalidTimezone(let z): return "Invalid IANA timezone: \(z)"
			case .invalidDate(let d): return "JalaliX.create: invalid date \(d)"
			case .invalidJalali(let v): return "JalaliX.parseJalali: invalid Jalali date \"\(v)\""
		}
	}
}
