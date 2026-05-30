import Foundation
import JavaScriptCore

print("==================================================")
print("       AURA PROGRAMMATIC TEST SUITE ENGINE        ")
print("==================================================")

var testsPassed = 0
var testsFailed = 0

func assertTest(_ condition: Bool, _ message: String) {
    if condition {
        print("✅ [PASS] \(message)")
        testsPassed += 1
    } else {
        print("❌ [FAIL] \(message)")
        testsFailed += 1
    }
}

// MARK: - JXA JavaScript Core Date Parser Verification
print("\n--- Running JXA JS Date Parser Tests ---")

guard let context = JSContext() else {
    print("❌ Fatal: Failed to initialize JavaScriptCore context")
    exit(1)
}

let parseDateJSCode = """
function parseDate(d) {
    if (!d) return null;
    try {
        if (typeof d === 'number') return d;
        if (d.getTime) {
            var t = d.getTime();
            if (!isNaN(t)) return t / 1000;
        }
        var s = d.toString();
        if (s) {
            var t = Date.parse(s);
            if (!isNaN(t)) return t / 1000;
            var d2 = new Date(s);
            if (d2 && d2.getTime) {
                var t2 = d2.getTime();
                if (!isNaN(t2)) return t2 / 1000;
            }
        }
    } catch(e) {}
    return null;
}
"""

context.evaluateScript(parseDateJSCode)
let parseDateFn = context.objectForKeyedSubscript("parseDate")!

// Test 1: Unix timestamp number (JXA sometimes yields double timestamps)
let tsNumber = 1716942000.0 // May 29, 2024
let resNumber = parseDateFn.call(withArguments: [tsNumber])!
assertTest(resNumber.toDouble() == tsNumber, "Parse numeric timestamp directly: \(resNumber.toDouble())")

// Test 2: ISO 8601 Date String (standard XML export / internet times)
let isoStr = "2026-05-30T18:28:46Z"
let resISO = parseDateFn.call(withArguments: [isoStr])!
// ISO string parse should match UTC 1780165726 (2026-05-30 18:28:46)
assertTest(resISO.toDouble() == 1780165726, "Parse standard ISO 8601 date string: \(resISO.toDouble())")

// Test 3: Localized Ventura/Sonoma Apple Events Scripting Bridge Date String Proxy
let localizedStr = "Saturday, May 30, 2026 at 6:28:46 PM"
let resLocal = parseDateFn.call(withArguments: [localizedStr])!
assertTest(resLocal.toDouble() > 0, "Parse localized scripting date proxy string: \(resLocal.toDouble())")

// Test 4: JavaScript native Date object mock
let makeNativeDateMock = """
var dateMock = new Date("2024-12-25T12:00:00Z");
parseDate(dateMock);
"""
let resNative = context.evaluateScript(makeNativeDateMock)!
assertTest(resNative.toDouble() == 1735128000, "Parse JS native Date object proxy: \(resNative.toDouble())")

// Test 5: Empty / invalid formats gracefully return null
let resNull = parseDateFn.call(withArguments: [NSNull()])!
assertTest(resNull.isNull, "Gracefully handles null or missing arguments")


// MARK: - Swift TimeFilter Logic Verification
print("\n--- Running Swift TimeFilter Logic Tests ---")

// Dummy Track matching Models.swift
struct TestTrack {
    let name: String
    let dateAdded: Double?
    
    var addedDate: Date? {
        guard let timestamp = dateAdded else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

enum TestTimeFilter {
    case allTime
    case specificYear(Int)
}

// Reference date for current time: 2026-05-30
let referenceDate = ISO8601DateFormatter().date(from: "2026-05-30T18:28:46Z")!
let calendar = Calendar.current

let mockTracks = [
    // Added in 2026 (Current Year)
    TestTrack(name: "Track A", dateAdded: ISO8601DateFormatter().date(from: "2026-02-14T10:00:00Z")!.timeIntervalSince1970),
    // Added in 2025 (Previous Year)
    TestTrack(name: "Track B", dateAdded: ISO8601DateFormatter().date(from: "2025-08-20T14:30:00Z")!.timeIntervalSince1970),
    // Added in 2024 (Two Years Ago)
    TestTrack(name: "Track C", dateAdded: ISO8601DateFormatter().date(from: "2024-11-30T09:15:00Z")!.timeIntervalSince1970),
    // Added in 2023 (Older)
    TestTrack(name: "Track D", dateAdded: ISO8601DateFormatter().date(from: "2023-05-05T12:00:00Z")!.timeIntervalSince1970)
]

func applyFilter(filter: TestTimeFilter, items: [TestTrack]) -> [TestTrack] {
    switch filter {
    case .allTime:
        return items
    case .specificYear(let targetYear):
        return items.filter { item in
            guard let added = item.addedDate else { return false }
            return calendar.component(.year, from: added) == targetYear
        }
    }
}

// 1. All Time Filter
let allTimeResult = applyFilter(filter: .allTime, items: mockTracks)
assertTest(allTimeResult.count == 4, "All Time returns all 4 tracks")

// 2. Year 2026 Filter
let year2026Result = applyFilter(filter: .specificYear(2026), items: mockTracks)
assertTest(year2026Result.count == 1 && year2026Result[0].name == "Track A", "Year 2026 filter returns only Track A")

// 3. Year 2025 Filter
let year2025Result = applyFilter(filter: .specificYear(2025), items: mockTracks)
assertTest(year2025Result.count == 1 && year2025Result[0].name == "Track B", "Year 2025 filter returns only Track B")

// 4. Year 2024 Filter
let year2024Result = applyFilter(filter: .specificYear(2024), items: mockTracks)
assertTest(year2024Result.count == 1 && year2024Result[0].name == "Track C", "Year 2024 filter returns only Track C")


// MARK: - Test Completion Summary
print("\n==================================================")
print("             TEST EXECUTION SUMMARY               ")
print("==================================================")
print("Total Tests Run: \(testsPassed + testsFailed)")
print("Tests Passed:    \(testsPassed)")
print("Tests Failed:    \(testsFailed)")
print("==================================================")

if testsFailed > 0 {
    print("❌ One or more tests have failed.")
    exit(1)
} else {
    print("🚀 All tests passed perfectly.")
    exit(0)
}
