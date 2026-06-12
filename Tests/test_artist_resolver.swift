import Foundation

print("==================================================")
print("     AURA ARTIST RESOLVER TEST SUITE ENGINE       ")
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

func assertResolves(_ input: String, to expected: [String], _ message: String) {
    let result = ArtistResolver.resolve(input)
    let match = result == expected
    if match {
        print("✅ [PASS] \(message)")
        testsPassed += 1
    } else {
        print("❌ [FAIL] \(message)")
        print("         Input:    \"\(input)\"")
        print("         Expected: \(expected)")
        print("         Got:      \(result)")
        testsFailed += 1
    }
}

// ============================================================
// Inline ArtistResolver (mirrors AuraApp/ArtistResolver.swift)
// ============================================================

struct ArtistResolver {
    
    private static let knownGroups: Set<String> = {
        let groups = [
            "Simon & Garfunkel",
            "Peter, Paul & Mary",
            "Crosby, Stills, Nash & Young",
            "Crosby, Stills & Nash",
            "Hall & Oates",
            "Daryl Hall & John Oates",
            "Brooks & Dunn",
            "Earth, Wind & Fire",
            "Emerson, Lake & Palmer",
            "Belle & Sebastian",
            "Hootie & the Blowfish",
            "Florence + the Machine",
            "Mumford & Sons",
            "Herb Alpert & the Tijuana Brass",
            "Tom Petty and the Heartbreakers",
            "Echo & the Bunnymen",
            "Sly & the Family Stone",
            "Josie and the Pussycats",
            "Huey Lewis and the News",
            "KC and the Sunshine Band",
            "Katrina and the Waves",
            "Prince and the Revolution",
            "Bob Marley & The Wailers",
            "Booker T. & the M.G.'s",
            "Derek and the Dominos",
            "Diana Ross & The Supremes",
            "Gladys Knight & the Pips",
            "Iggy and the Stooges",
            "Joan Jett & the Blackhearts",
            "Martha and the Vandellas",
            "Nick Cave & The Bad Seeds",
            "Rage Against the Machine",
            "Stevie Ray Vaughan and Double Trouble",
            "The Mamas & the Papas",
            "Above & Beyond",
            "Chase & Status",
            "Aly & Fila",
            "Gabriel & Dresden",
            "Sasha & John Digweed",
            "Daft Punk",
            "Boards of Canada",
            "Thievery Corporation",
            "MGMT",
            "Tegan and Sara",
            "Dan + Shay",
            "for KING & COUNTRY",
            "Macklemore & Ryan Lewis",
            "She & Him",
            "Sugarland",
            "Civil Wars",
            "Phantogram",
            "Brooks & Dunn",
            "Montgomery Gentry",
            "Florida Georgia Line",
            "Bach, Johann Sebastian",
            "Beethoven, Ludwig van",
            "Mozart, Wolfgang Amadeus",
            "Chopin, Frédéric",
            "Chopin, Frederic",
            "Liszt, Franz",
            "Brahms, Johannes",
            "Tchaikovsky, Pyotr Ilyich",
            "Debussy, Claude",
            "Ravel, Maurice",
            "Schubert, Franz",
            "Handel, George Frideric",
            "Vivaldi, Antonio",
            "Strauss, Johann",
            "Strauss, Richard",
            "Dvořák, Antonín",
            "Dvorak, Antonin",
            "Mendelssohn, Felix",
            "Rachmaninoff, Sergei",
            "Rachmaninov, Sergei",
            "Prokofiev, Sergei",
            "Shostakovich, Dmitri",
            "Verdi, Giuseppe",
            "Puccini, Giacomo",
            "Wagner, Richard",
            "Mahler, Gustav",
            "Elgar, Edward",
            "Grieg, Edvard",
            "Sibelius, Jean",
            "Saint-Saëns, Camille",
            "Berlioz, Hector",
        ]
        return Set(groups.map { $0.lowercased() })
    }()
    
    static func resolve(_ rawArtist: String) -> [String] {
        let trimmed = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [rawArtist] }
        if knownGroups.contains(trimmed.lowercased()) { return [trimmed] }
        if isLastFirstFormat(trimmed) { return [trimmed] }
        if !containsAnyDelimiter(trimmed) { return [trimmed] }
        
        var segments = [trimmed]
        segments = segments.flatMap { splitOnCommas($0) }
        segments = segments.flatMap { splitOnConjunctions($0) }
        
        var seen = Set<String>()
        var result: [String] = []
        for segment in segments {
            let cleaned = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let key = cleaned.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(cleaned)
            }
        }
        return result.isEmpty ? [trimmed] : result
    }
    
    private static func isLastFirstFormat(_ s: String) -> Bool {
        let commaCount = s.filter { $0 == "," }.count
        guard commaCount == 1 else { return false }
        let parts = s.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return false }
        let leftWords = parts[0].split(separator: " ").count
        let rightWords = parts[1].split(separator: " ").count
        return leftWords == 1 && rightWords <= 2
    }
    
    private static func containsAnyDelimiter(_ s: String) -> Bool {
        if s.contains(",") || s.contains("&") || s.contains("+") { return true }
        let lower = s.lowercased()
        let patterns = [" feat. ", " feat ", " ft. ", " ft ", " featuring ", " x ", " vs. ", " vs ", " and ", " with "]
        return patterns.contains { lower.contains($0) }
    }
    
    private static func splitOnCommas(_ s: String) -> [String] {
        guard s.contains(",") else { return [s] }
        if knownGroups.contains(s.lowercased().trimmingCharacters(in: .whitespaces)) { return [s] }
        if isLastFirstFormat(s) { return [s] }
        return s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    
    private static func splitOnConjunctions(_ s: String) -> [String] {
        if knownGroups.contains(s.lowercased().trimmingCharacters(in: .whitespaces)) { return [s] }
        
        let delimiters = [" featuring ", " feat. ", " feat ", " ft. ", " ft ", " vs. ", " vs "]
        for delimiter in delimiters {
            if let range = s.range(of: delimiter, options: .caseInsensitive) {
                let left = String(s[s.startIndex..<range.lowerBound])
                let right = String(s[range.upperBound...])
                return splitOnConjunctions(left) + splitOnConjunctions(right)
            }
        }
        
        let ampersandDelimiters = [" & ", " + "]
        for delimiter in ampersandDelimiters {
            if let range = s.range(of: delimiter, options: .caseInsensitive) {
                let left = String(s[s.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let right = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let rightLower = right.lowercased()
                if rightLower.hasPrefix("the ") || rightLower.hasPrefix("his ") || rightLower.hasPrefix("her ") {
                    return [s]
                }
                return [left] + splitOnConjunctions(right)
            }
        }
        
        if let range = s.range(of: " and ", options: .caseInsensitive) {
            let left = String(s[s.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            let rightLower = right.lowercased()
            if rightLower.hasPrefix("the ") || rightLower.hasPrefix("his ") || rightLower.hasPrefix("her ") {
                return [s]
            }
            return [left] + splitOnConjunctions(right)
        }
        
        if let range = s.range(of: " with ", options: .caseInsensitive) {
            let left = String(s[s.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            let rightLower = right.lowercased()
            if rightLower.hasPrefix("the ") { return [s] }
            return [left] + splitOnConjunctions(right)
        }
        
        return [s]
    }
}


// ==================================================
// MARK: - Solo Artists (no splitting)
// ==================================================
print("\n--- Solo Artists ---")

assertResolves("Adele", to: ["Adele"], "Solo artist: plain name")
assertResolves("Hans Zimmer", to: ["Hans Zimmer"], "Solo artist: two-word name")
assertResolves("The Midnight", to: ["The Midnight"], "Solo artist: band with 'The'")
assertResolves("  Adele  ", to: ["Adele"], "Solo artist: whitespace trimmed")
assertResolves("", to: [""], "Empty string returns as-is")

// ==================================================
// MARK: - Known Groups (protected from splitting)
// ==================================================
print("\n--- Known Groups ---")

assertResolves("Simon & Garfunkel", to: ["Simon & Garfunkel"], "Known group: Simon & Garfunkel")
assertResolves("Peter, Paul & Mary", to: ["Peter, Paul & Mary"], "Known group: Peter, Paul & Mary")
assertResolves("Earth, Wind & Fire", to: ["Earth, Wind & Fire"], "Known group: Earth, Wind & Fire")
assertResolves("Crosby, Stills, Nash & Young", to: ["Crosby, Stills, Nash & Young"], "Known group: CSNY")
assertResolves("Emerson, Lake & Palmer", to: ["Emerson, Lake & Palmer"], "Known group: ELP")
assertResolves("Florence + the Machine", to: ["Florence + the Machine"], "Known group: Florence + the Machine")
assertResolves("Mumford & Sons", to: ["Mumford & Sons"], "Known group: Mumford & Sons")
assertResolves("Above & Beyond", to: ["Above & Beyond"], "Known group: Above & Beyond")
assertResolves("Dan + Shay", to: ["Dan + Shay"], "Known group: Dan + Shay")
assertResolves("Tegan and Sara", to: ["Tegan and Sara"], "Known group: Tegan and Sara")
assertResolves("Hootie & the Blowfish", to: ["Hootie & the Blowfish"], "Known group: Hootie & the Blowfish")
assertResolves("Bob Marley & The Wailers", to: ["Bob Marley & The Wailers"], "Known group: Bob Marley & The Wailers")

// Case-insensitive matching
assertResolves("simon & garfunkel", to: ["simon & garfunkel"], "Known group: case-insensitive match")
assertResolves("EARTH, WIND & FIRE", to: ["EARTH, WIND & FIRE"], "Known group: all-caps match")

// ==================================================
// MARK: - Classical Composers ("Last, First")
// ==================================================
print("\n--- Classical Composers (Last, First) ---")

assertResolves("Chopin, Frederic", to: ["Chopin, Frederic"], "Last, First: Chopin, Frederic")
assertResolves("Chopin, Frédéric", to: ["Chopin, Frédéric"], "Last, First: Chopin, Frédéric (accented)")
assertResolves("Liszt, Franz", to: ["Liszt, Franz"], "Last, First: Liszt, Franz")
assertResolves("Debussy, Claude", to: ["Debussy, Claude"], "Last, First: Debussy, Claude")
assertResolves("Bach, Johann Sebastian", to: ["Bach, Johann Sebastian"], "Last, First Middle: Bach (known group)")

// ==================================================
// MARK: - Collaborations (should split)
// ==================================================
print("\n--- Collaborations ---")

assertResolves("DT James & Kimbo", to: ["DT James", "Kimbo"], "Ampersand split: DT James & Kimbo")
assertResolves("Drake feat. Future", to: ["Drake", "Future"], "Feat. split: Drake feat. Future")
assertResolves("Drake ft. Future", to: ["Drake", "Future"], "Ft. split: Drake ft. Future")
assertResolves("Drake featuring Future", to: ["Drake", "Future"], "Featuring split: Drake featuring Future")
assertResolves("Jay-Z & Kanye West", to: ["Jay-Z", "Kanye West"], "Ampersand split: Jay-Z & Kanye West")

// ==================================================
// MARK: - Multiple Artists (commas + conjunctions)
// ==================================================
print("\n--- Multiple Artists (complex) ---")

assertResolves("Drake, Future & Metro Boomin", to: ["Drake", "Future", "Metro Boomin"], "Mixed: comma + ampersand (3 artists)")
assertResolves("A, B, C", to: ["A", "B", "C"], "Pure comma split: 3 artists")
assertResolves("Skrillex & Diplo feat. Justin Bieber", to: ["Skrillex", "Diplo", "Justin Bieber"], "Ampersand + feat: 3 artists")

// ==================================================
// MARK: - "X & the Y" Heuristic (should NOT split)
// ==================================================
print("\n--- 'X & the Y' Heuristic ---")

assertResolves("Rage & the Machine", to: ["Rage & the Machine"], "Heuristic: '& the' → don't split")
assertResolves("Some Band & the Orchestra", to: ["Some Band & the Orchestra"], "Heuristic: '& the' → don't split (generic)")

// ==================================================
// MARK: - Edge Cases
// ==================================================
print("\n--- Edge Cases ---")

assertResolves("Unknown Artist", to: ["Unknown Artist"], "Default: Unknown Artist passes through")
assertResolves("экспериментальный", to: ["экспериментальный"], "Non-latin script: passes through unsplit")
assertResolves("DJ Boring", to: ["DJ Boring"], "No delimiters: passes through")
assertResolves("Alt-J", to: ["Alt-J"], "Hyphen name: passes through")

// Deduplication
assertResolves("Drake & Drake", to: ["Drake"], "Deduplication: duplicate names")


// ==================================================
// MARK: - Test Summary
// ==================================================
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
