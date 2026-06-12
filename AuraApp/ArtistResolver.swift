import Foundation

/// Resolves compound artist fields (e.g. "DT James & Kimbo") into individual artist names
/// for analytics aggregation, while preserving known groups/bands/duos and "Last, First" formatted names.
///
/// This operates at the analytics layer only — `Track.artist` remains the raw string from Apple Music.
struct ArtistResolver {
    
    // MARK: - Known Groups / Bands / Duos
    
    /// Artists/groups whose names legitimately contain delimiters like "&", ",", "feat.", "+".
    /// These are protected from splitting. Case-insensitive lookup.
    ///
    /// Extend this set as new edge cases are discovered.
    private static let knownGroups: Set<String> = {
        let groups = [
            // Classic groups with "&"
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
            
            // Electronic / DJ duos with "&"
            "Above & Beyond",
            "Chase & Status",
            "Aly & Fila",
            "Gabriel & Dresden",
            "Sasha & John Digweed",
            "Daft Punk",
            "Boards of Canada",
            "Thievery Corporation",
            
            // Modern / Pop / Hip-Hop groups
            "MGMT",
            "Tegan and Sara",
            "Dan + Shay",
            "for KING & COUNTRY",
            "Macklemore & Ryan Lewis",
            "She & Him",
            "Sugarland",
            "Civil Wars",
            "Phantogram",
            
            // Country
            "Brooks & Dunn",
            "Montgomery Gentry",
            "Sugarland",
            "Florida Georgia Line",
            
            // Classical composers in "Last, First" format
            // (also caught by the "Last, First" heuristic, but listed here for safety)
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
        // Store lowercased for case-insensitive lookup
        return Set(groups.map { $0.lowercased() })
    }()
    
    // MARK: - Public API
    
    /// Resolves a raw artist string into an array of individual artist names.
    ///
    /// Examples:
    /// - `"Adele"` → `["Adele"]`
    /// - `"DT James & Kimbo"` → `["DT James", "Kimbo"]`
    /// - `"Drake feat. Future"` → `["Drake", "Future"]`
    /// - `"Simon & Garfunkel"` → `["Simon & Garfunkel"]` (known group)
    /// - `"Chopin, Frederic"` → `["Chopin, Frederic"]` (Last, First pattern)
    /// - `"Drake, Future & Metro Boomin"` → `["Drake", "Future", "Metro Boomin"]`
    static func resolve(_ rawArtist: String) -> [String] {
        let trimmed = rawArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return [rawArtist] }
        
        // 1. Known groups — never split these
        if knownGroups.contains(trimmed.lowercased()) {
            return [trimmed]
        }
        
        // 2. "Last, First" heuristic: exactly one comma, and the result is ≤ 3 words total.
        //    Catches "Chopin, Frederic", "Bach, Johann Sebastian", etc.
        if isLastFirstFormat(trimmed) {
            return [trimmed]
        }
        
        // 3. Check if there are any delimiters worth splitting on — fast path
        if !containsAnyDelimiter(trimmed) {
            return [trimmed]
        }
        
        // 4. Multi-pass splitting: commas first, then conjunctions/featuring
        var segments = [trimmed]
        segments = segments.flatMap { splitOnCommas($0) }
        segments = segments.flatMap { splitOnConjunctions($0) }
        
        // 5. Clean up: trim whitespace, remove empty strings, deduplicate preserving order
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
    
    // MARK: - Private Helpers
    
    /// Detects "Last, First" format: exactly one comma, and the full string is ≤ 3 words.
    /// Examples that match: "Chopin, Frederic", "Bach, Johann Sebastian"
    /// Examples that don't: "Drake, Future, Metro Boomin" (multiple commas), "A, B" where A and B could be artists
    private static func isLastFirstFormat(_ s: String) -> Bool {
        let commaCount = s.filter { $0 == "," }.count
        guard commaCount == 1 else { return false }
        
        // Split on comma
        let parts = s.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return false }
        
        let leftWords = parts[0].split(separator: " ").count
        let rightWords = parts[1].split(separator: " ").count
        
        // "Last, First" or "Last, First Middle" — left side is typically 1 word (surname),
        // right side is 1-2 words (given name + optional middle name)
        // Total words ≤ 3 to be safe
        return leftWords == 1 && rightWords <= 2
    }
    
    /// Quick check for any delimiter character/pattern in the string
    private static func containsAnyDelimiter(_ s: String) -> Bool {
        // Check for common single characters first
        if s.contains(",") || s.contains("&") || s.contains("+") { return true }
        
        // Check for multi-word delimiters (case-insensitive)
        let lower = s.lowercased()
        let patterns = [" feat. ", " feat ", " ft. ", " ft ", " featuring ", " x ", " vs. ", " vs ", " and ", " with "]
        return patterns.contains { lower.contains($0) }
    }
    
    /// Splits on commas. Each resulting segment is checked against knownGroups before splitting further.
    private static func splitOnCommas(_ s: String) -> [String] {
        guard s.contains(",") else { return [s] }
        
        // Don't split known groups
        if knownGroups.contains(s.lowercased().trimmingCharacters(in: .whitespaces)) {
            return [s]
        }
        
        // Don't split "Last, First" format
        if isLastFirstFormat(s) {
            return [s]
        }
        
        return s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    
    /// Splits on conjunction/featuring delimiters: " & ", " feat. ", " ft. ", " featuring ", " x ", " and ", " with ", " + "
    private static func splitOnConjunctions(_ s: String) -> [String] {
        // Don't split known groups
        if knownGroups.contains(s.lowercased().trimmingCharacters(in: .whitespaces)) {
            return [s]
        }
        
        // Ordered by specificity (longer patterns first to avoid partial matches)
        let delimiters = [
            " featuring ",
            " feat. ",
            " feat ",
            " ft. ",
            " ft ",
            " vs. ",
            " vs ",
        ]
        
        // Try each delimiter — split on the first one found
        // These are "featured" type delimiters: split into exactly 2 parts
        for delimiter in delimiters {
            if let range = s.range(of: delimiter, options: .caseInsensitive) {
                let left = String(s[s.startIndex..<range.lowerBound])
                let right = String(s[range.upperBound...])
                // Recursively resolve both sides (left may contain "&", right may contain "feat.")
                return splitOnConjunctions(left) + splitOnConjunctions(right)
            }
        }
        
        // " & " and " and " — split into multiple parts
        // But first check if it's a known "X & the Y" pattern
        let ampersandDelimiters = [" & ", " + "]
        for delimiter in ampersandDelimiters {
            if let range = s.range(of: delimiter, options: .caseInsensitive) {
                let left = String(s[s.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let right = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                
                // Heuristic: if right side starts with "the " or "his " or "her ",
                // it's likely a band name like "X & the Ys" — don't split
                let rightLower = right.lowercased()
                if rightLower.hasPrefix("the ") || rightLower.hasPrefix("his ") || rightLower.hasPrefix("her ") {
                    return [s]
                }
                
                return [left] + splitOnConjunctions(right)
            }
        }
        
        // " and " — only split if it doesn't look like a band name
        if let range = s.range(of: " and ", options: .caseInsensitive) {
            let left = String(s[s.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Heuristic: if right side starts with "the " or left+right are both short single names,
            // it might be a band. "Tegan and Sara" is in knownGroups already.
            let rightLower = right.lowercased()
            if rightLower.hasPrefix("the ") || rightLower.hasPrefix("his ") || rightLower.hasPrefix("her ") {
                return [s]
            }
            
            return [left] + splitOnConjunctions(right)
        }
        
        // " with " — only split for featuring-style usage
        if let range = s.range(of: " with ", options: .caseInsensitive) {
            let left = String(s[s.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(s[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Only split if left side looks like an artist name (has at least 2 characters)
            // and right side doesn't start with "the" (band pattern)
            let rightLower = right.lowercased()
            if rightLower.hasPrefix("the ") {
                return [s]
            }
            
            return [left] + splitOnConjunctions(right)
        }
        
        return [s]
    }
}
