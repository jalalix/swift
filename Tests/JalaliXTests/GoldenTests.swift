import XCTest
@testable import JalaliX

final class GoldenTests: XCTestCase {
	private var golden: [String: Any] = [:]

	override func setUpWithError() throws {
		let url = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent() // JalaliXTests
			.deletingLastPathComponent() // Tests
			.deletingLastPathComponent() // package root
			.appendingPathComponent("testdata/golden.json")
		
		let data = try Data(contentsOf: url)
		let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
		XCTAssertEqual(obj?["version"] as? Int, 1)
		golden = obj ?? [:]
	}

	private func createFrom(_ spec: [String: Any]) throws -> JalaliX {
		if let unixMs = spec["unixMs"] as? Int64 {
			var d = try JalaliX.create(unixMs: unixMs)

			if let tz = spec["timezone"] as? String {
				d = try d.setTimezone(tz)
			}

			return d
		}

		if let unixMs = spec["unixMs"] as? Int {
			var d = try JalaliX.create(unixMs: Int64(unixMs))
			if let tz = spec["timezone"] as? String {
				d = try d.setTimezone(tz)
			}
			return d
		}

		// JSON numbers may decode as NSNumber
		if let num = spec["unixMs"] as? NSNumber {
			var d = try JalaliX.create(unixMs: num.int64Value)

			if let tz = spec["timezone"] as? String {
				d = try d.setTimezone(tz)
			}

			return d
		}

		let iso = spec["isoDate"] as! String
		return try JalaliX.create(isoDate: iso)
	}

	func testCalendar() throws {
		let cases = golden["calendar"] as! [[String: Any]]

		for c in cases {
			let d = try createFrom(c["create"] as! [String: Any])
			let expect = c["expect"] as! [String: Any]
			let id = c["id"] as! String
			XCTAssertEqual(d.format("YYYY/MM/DD"), expect["formatYYYYMMDD"] as? String, id)
			XCTAssertEqual(d.toISODate(), expect["toISODateGregorian"] as? String, id)
			XCTAssertEqual(d.toISODate("jalali"), expect["toISODateJalali"] as? String, id)
		}
	}

	func testParse() throws {
		let cases = golden["parse"] as! [[String: Any]]

		for c in cases {
			let d = try JalaliX.parseJalali(c["input"] as! String)
			let expect = c["expect"] as! [String: Any]
			let id = c["id"] as! String
			XCTAssertEqual(d.toISODate(), expect["toISODateGregorian"] as? String, id)

			if let fmt = expect["formatYYYYMMDD"] as? String {
				XCTAssertEqual(d.format("YYYY/MM/DD"), fmt, id)
			}
		}
	}

	func testFormat() throws {
		let cases = golden["format"] as! [[String: Any]]

		for c in cases {
			if let toPersian = c["toPersian"] as? [String: Any] {
				XCTAssertEqual(JalaliX.toPersian(toPersian["input"] as! String), toPersian["expect"] as? String)
				let fromPersian = c["fromPersian"] as! [String: Any]
				XCTAssertEqual(JalaliX.fromPersian(fromPersian["input"] as! String), fromPersian["expect"] as? String)
				continue
			}

			let d = try createFrom(c["create"] as! [String: Any])
			var options: [String: Any] = [:]

			if let opts = c["options"] as? [String: Any] {
				if let pd = opts["persianDigits"] as? Bool { options["persianDigits"] = pd }
				if let cal = opts["calendar"] as? String { options["calendar"] = cal }
			}

			let id = c["id"] as! String
			XCTAssertEqual(d.format(c["pattern"] as! String, options: options.isEmpty ? nil : options), c["expect"] as? String, id)
		}
	}

	func testTimezone() throws {
		let cases = golden["timezone"] as! [[String: Any]]

		for c in cases {
			let id = c["id"] as! String

			if let alias = c["setTimezoneAlias"] as? String {
				let unix = (c["unixMs"] as! NSNumber).int64Value
				let d = try JalaliX.create(unixMs: unix).setTimezone(alias)
				XCTAssertEqual(d.getTimezone(), c["expectTimezone"] as? String, id)
				continue
			}

			let unix = (c["unixMs"] as! NSNumber).int64Value
			let timezone = c["withTimezone"] as! String
			let d = try JalaliX.create(unixMs: unix).setTimezone(timezone)
			let expect = c["expect"] as! [String: Any]
			XCTAssertEqual(d.format("YYYY/MM/DD"), expect["jalaliSlash"] as? String, id)

			if let jalaliIso = expect["jalaliIso"] as? String {
				XCTAssertEqual(d.toISODate("jalali"), jalaliIso, id)
			}

			if let wallG = expect["wallGregorian"] as? String {
				XCTAssertEqual(d.toISODate(), wallG, id)
			}

			if let wallTime = expect["wallTime"] as? String {
				XCTAssertEqual(d.format("HH:mm:ss"), wallTime, id)
			}

			XCTAssertEqual(d.getHours(), expect["hours"] as? Int, id)
			XCTAssertEqual(d.getMinutes(), expect["minutes"] as? Int, id)

			if let getTime = expect["getTime"] as? NSNumber {
				XCTAssertEqual(d.getTime(), getTime.int64Value, id)
			}
		}
	}

	func testMutations() throws {
		let cases = golden["mutations"] as! [[String: Any]]

		for c in cases {
			var d = try createFrom(c["create"] as! [String: Any])
			let id = c["id"] as! String

			if let sfy = c["setFullYear"] as? [String: Any] {
				_ = d.setFullYear(sfy["year"] as! Int, (sfy["month0"] as! Int), (sfy["day"] as! Int))
				let expect = c["expect"] as! [String: Any]
				XCTAssertEqual(d.getMonth(), expect["getMonth"] as? Int, id)
				XCTAssertEqual(d.format("YYYY/MM/DD"), expect["formatYYYYMMDD"] as? String, id)
				continue
			}

			for op in c["ops"] as! [String] {
				if op.hasPrefix("addMonths:") {
					let n = Int(op.split(separator: ":")[1])!
					d = d.addMonths(n)
				} else if op == "getStartOfMonth" {
					d = d.getStartOfMonth()
				}
			}

			let expect = c["expect"] as! [String: Any]
			XCTAssertEqual(d.format("YYYY/MM/DD"), expect["formatYYYYMMDD"] as? String, id)
		}
	}
}
