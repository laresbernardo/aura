import Foundation

// Track Model from Models.swift
struct Track: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let artist: String
    let album: String
    let genre: String
    let playCount: Int
    let skipCount: Int
    let rating: Int // 0-100
    let dateAdded: Double? // Unix Timestamp
    let lastPlayed: Double? // Unix Timestamp
    let year: Int
    
    enum CodingKeys: String, CodingKey {
        case name, artist, album, genre, playCount, skipCount, rating, dateAdded, lastPlayed, year
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Track"
        self.artist = (try? container.decode(String.self, forKey: .artist)) ?? "Unknown Artist"
        self.album = (try? container.decode(String.self, forKey: .album)) ?? "Unknown Album"
        self.genre = (try? container.decode(String.self, forKey: .genre)) ?? "Unknown Genre"
        self.playCount = (try? container.decode(Int.self, forKey: .playCount)) ?? 0
        self.skipCount = (try? container.decode(Int.self, forKey: .skipCount)) ?? 0
        self.rating = (try? container.decode(Int.self, forKey: .rating)) ?? 0
        self.dateAdded = try? container.decode(Double.self, forKey: .dateAdded)
        self.lastPlayed = try? container.decode(Double.self, forKey: .lastPlayed)
        self.year = (try? container.decode(Int.self, forKey: .year)) ?? 0
    }
    
    init(name: String, artist: String, album: String, genre: String, playCount: Int, skipCount: Int, rating: Int, dateAdded: Double?, lastPlayed: Double?, year: Int) {
        self.id = UUID()
        self.name = name
        self.artist = artist
        self.album = album
        self.genre = genre
        self.playCount = playCount
        self.skipCount = skipCount
        self.rating = rating
        self.dateAdded = dateAdded
        self.lastPlayed = lastPlayed
        self.year = year
    }
    
    var addedDate: Date? {
        guard let timestamp = dateAdded else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

// Copy newestXML and path discovery from MusicLibraryManager
func newestXML(in dir: URL) -> URL? {
    let fm = FileManager.default
    guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
        return nil
    }
    let xmlFiles = contents.filter { url in
        let name = url.lastPathComponent.lowercased()
        return name.hasSuffix(".xml") && (name.contains("library") || name.contains("itunes"))
    }
    return xmlFiles.sorted { url1, url2 in
        let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
        let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
        return date1 > date2
    }.first
}

func musicLibraryXMLURL() -> URL? {
    let prefsPath = NSHomeDirectory() + "/Library/Preferences/com.apple.Music.plist"
    if let prefsData = try? Data(contentsOf: URL(fileURLWithPath: prefsPath)),
       let prefs = try? PropertyListSerialization.propertyList(from: prefsData, format: nil) as? [String: Any],
       let rawURL = prefs["library-url"] as? String,
       let encodedURL = URL(string: rawURL) {
        let bundlePath = encodedURL.path
        let bundleURL  = URL(fileURLWithPath: bundlePath)
        let parentDir  = bundleURL.deletingLastPathComponent()
        if let found = newestXML(in: parentDir) { return found }
        let backupsDir = parentDir.appendingPathComponent("Backups")
        if let found = newestXML(in: backupsDir) { return found }
    }
    return nil
}

guard let xmlURL = musicLibraryXMLURL() else {
    print("❌ Could not find XML URL")
    exit(1)
}

guard let data = try? Data(contentsOf: xmlURL) else {
    print("❌ Could not read data")
    exit(1)
}

guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
      let tracksDict = plist["Tracks"] as? [String: Any] else {
    print("❌ Could not parse XML plist")
    exit(1)
}

let isoFormatter = ISO8601DateFormatter()
var tracks: [Track] = []

for (_, value) in tracksDict {
    guard let info = value as? [String: Any] else { continue }
    if let kind = info["Track Type"] as? String, kind != "File" { continue }

    let name      = info["Name"]   as? String ?? "Unknown Track"
    let artist    = info["Artist"] as? String ?? "Unknown Artist"
    let album     = info["Album"]  as? String ?? "Unknown Album"
    let genre     = info["Genre"]  as? String ?? "Unknown Genre"
    let playCount = info["Play Count"]  as? Int ?? 0
    let skipCount = info["Skip Count"]  as? Int ?? 0
    let rating    = info["Rating"]       as? Int ?? 0
    let year      = info["Year"]         as? Int ?? 0

    var dateAdded: Double? = nil
    if let d = info["Date Added"] as? Date {
        dateAdded = d.timeIntervalSince1970
    } else if let s = info["Date Added"] as? String,
              let d = isoFormatter.date(from: s) {
        dateAdded = d.timeIntervalSince1970
    }

    var lastPlayed: Double? = nil
    if let d = info["Play Date UTC"] as? Date {
        lastPlayed = d.timeIntervalSince1970
    } else if let s = info["Play Date UTC"] as? String,
              let d = isoFormatter.date(from: s) {
        lastPlayed = d.timeIntervalSince1970
    }

    tracks.append(Track(
        name: name, artist: artist, album: album, genre: genre,
        playCount: playCount, skipCount: skipCount, rating: rating,
        dateAdded: dateAdded, lastPlayed: lastPlayed, year: year
    ))
}

print("Total parsed tracks: \(tracks.count)")

let cal = Calendar.current
var parsedYearsDist: [Int: Int] = [:]
for t in tracks {
    if let added = t.addedDate {
        let y = cal.component(.year, from: added)
        parsedYearsDist[y, default: 0] += 1
    }
}

print("Parsed Tracks addedYear distribution:")
for yr in parsedYearsDist.keys.sorted() {
    print("  \(yr): \(parsedYearsDist[yr]!)")
}
