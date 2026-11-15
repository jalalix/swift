import XCTest
@testable import JalaliX

final class NormalizeQueryDateTests: XCTestCase {
	func testFromPersianArabicIndic() {
		XCTAssertEqual(JalaliX.fromPersian("۱۴۰۳/۱۲/۰۷"), "1403/12/07")
		XCTAssertEqual(JalaliX.fromPersian("١٤٠٣/١٢/٠٧"), "1403/12/07")
	}

	func testParseJalaliDotSeparator() throws {
		let d = try JalaliX.parseJalali("1403.12.07")
		XCTAssertEqual(d.toISODate(), "2025-02-25")
	}

	func testNormalizeQuerySentinelsAndTimestamps() {
		XCTAssertNil(JalaliX.normalizeQueryDate(nil))
		XCTAssertNil(JalaliX.normalizeQueryDate("null"))
		XCTAssertNil(JalaliX.normalizeQueryDate(""))
		XCTAssertNil(JalaliX.normalizeQueryDate("undefined"))
		XCTAssertNil(JalaliX.normalizeQueryDate("Invalid Date"))
		XCTAssertNil(JalaliX.normalizeQueryDate("NaN"))
		XCTAssertNil(JalaliX.normalizeQueryDate(0))
		XCTAssertNil(JalaliX.normalizeQueryDate(-1))

		let seconds: Int64 = 1_740_430_800

		XCTAssertEqual(
			JalaliX.normalizeQueryDate(seconds, options: ["timezone": "UTC"]) as? String,
			"2025-02-24 21:00:00"
		)
		XCTAssertEqual(
			JalaliX.normalizeQueryDate(seconds * 1000, options: ["timezone": "Asia/Tehran"]) as? String,
			"2025-02-25 00:30:00"
		)
	}

	func testNormalizeQueryJalaliAndGregorian() {
		XCTAssertEqual(
			JalaliX.normalizeQueryDate("1403/12/07", options: ["timezone": "UTC"]) as? String,
			"2025-02-25 00:00:00"
		)
		XCTAssertEqual(
			JalaliX.normalizeQueryDate("۱۴۰۳-۱۲-۰۷ 14:30:00", options: ["timezone": "UTC"]) as? String,
			"2025-02-25 14:30:00"
		)
		XCTAssertEqual(
			JalaliX.normalizeQueryDate("2025.02.25") as? String,
			"2025-02-25 00:00:00"
		)
		XCTAssertEqual(
			JalaliX.normalizeQueryDate("2025-02-25 12:30:45.123Z") as? String,
			"2025-02-25 12:30:45"
		)
		XCTAssertEqual(JalaliX.normalizeQueryDate("not-a-date") as? String, "not-a-date")
		XCTAssertEqual(
			JalaliX.normalizeQueryDate("2025-01-01") as? String,
			"2025-01-01 00:00:00"
		)
	}
}
