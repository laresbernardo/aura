import Foundation
import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

@MainActor
class MusicLibraryManager: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var isLoading: Bool = false
    @Published var syncError: String? = nil
    @Published var isDemoMode: Bool = true // Default to true for a stunning first-use experience
    @Published var musicAppRunningState: MusicAppState = .unknown
    
    enum MusicAppState {
        case unknown
        case running
        case notRunning
        case permissionDenied
    }
    
    init() {
        loadDemoLibrary()
    }
    
    // Toggle between live library and demo library
    func toggleMode() {
        isDemoMode.toggle()
        if isDemoMode {
            loadDemoLibrary()
            syncError = nil
        } else {
            Task {
                await fetchLiveLibrary()
            }
        }
    }
    
    // Open Music app (optional; not required since we read the XML directly)
    func launchMusicApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Music"]
        try? process.run()
    }
    
    // MARK: - Live Library Fetching (XML file — no permissions required)

    func fetchLiveLibrary() async {
        self.isLoading = true
        self.syncError = nil
        self.musicAppRunningState = .running

        let result = await Task.detached(priority: .userInitiated) {
            Self.readLibraryFromXML()
        }.value

        switch result {
        case .success(let fetchedTracks):
            if fetchedTracks.isEmpty {
                self.syncError = "Your Music library appears to be empty."
            } else {
                self.tracks = fetchedTracks
                self.syncError = nil
            }
        case .failure(let error):
            self.syncError = error.localizedDescription
        }

        self.isLoading = false
    }

    // MARK: - Manual XML Selection File Dialog
    
    func selectXMLFileManually() async {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Exported Music Library XML"
        openPanel.message = "Choose the 'Library.xml' or 'Music Library.xml' file exported from Music.app"
        openPanel.prompt = "Select XML"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.xml, .propertyList]
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            UserDefaults.standard.set(url.path, forKey: "customXMLPath")
            await fetchLiveLibrary()
        }
    }
    
    func clearCustomXMLPath() async {
        UserDefaults.standard.removeObject(forKey: "customXMLPath")
        await fetchLiveLibrary()
    }

    // Discover the Music library XML path from Music's own preferences,
    // then parse it as an Apple plist — no sandbox or TCC permissions needed.
    private nonisolated static func readLibraryFromXML() -> Result<[Track], Error> {
        // 1. Find the library-url stored by Music.app in its preferences
        guard let libraryURL = musicLibraryXMLURL() else {
            return .failure(NSError(
                domain: "AuraXMLError", code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Could not locate your Music Library XML file. Aura searched next to your library bundle and in the Backups/ folder.\n\nPlease use the Export option: in Music.app choose File → Library → Export Library… and save as iTunes XML anywhere, then retry."
                ]
            ))
        }

        // 2. Load raw data
        guard let data = try? Data(contentsOf: libraryURL) else {
            return .failure(NSError(
                domain: "AuraXMLError", code: 2,
                userInfo: [NSLocalizedDescriptionKey:
                    "Found library at \(libraryURL.path) but could not read it. Make sure Music.app has written the XML export (Settings → Files → Share Music Library XML)."
                ]
            ))
        }

        // 3. Parse as an Apple property list
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let tracksDict = plist["Tracks"] as? [String: Any] else {
            return .failure(NSError(
                domain: "AuraXMLError", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Music Library XML format was unrecognised."]
            ))
        }

        // 4. Map each track entry to our Track model
        let isoFormatter = ISO8601DateFormatter()
        var tracks: [Track] = []
        tracks.reserveCapacity(tracksDict.count)

        for (_, value) in tracksDict {
            guard let info = value as? [String: Any] else { continue }

            // Skip non-file track types (radio streams, videos, etc.)
            if let kind = info["Track Type"] as? String, kind != "File" { continue }

            let name      = info["Name"]   as? String ?? "Unknown Track"
            let artist    = info["Artist"] as? String ?? "Unknown Artist"
            let album     = info["Album"]  as? String ?? "Unknown Album"
            let genre     = info["Genre"]  as? String ?? "Unknown Genre"
            let playCount = info["Play Count"]  as? Int ?? 0
            let skipCount = info["Skip Count"]  as? Int ?? 0
            let rating    = info["Rating"]       as? Int ?? 0
            let year      = info["Year"]         as? Int ?? 0

            // Date Added — stored as ISO 8601 date in the XML plist
            var dateAdded: Double? = nil
            if let d = info["Date Added"] as? Date {
                dateAdded = d.timeIntervalSince1970
            } else if let s = info["Date Added"] as? String,
                      let d = isoFormatter.date(from: s) {
                dateAdded = d.timeIntervalSince1970
            }

            // Last Played — "Play Date UTC" in the XML
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

        return .success(tracks)
    }

    // Resolves the Music Library XML path.
    // Music 1.4+ (macOS Ventura+) removed the "Share XML" option, so the canonical XML
    // is no longer written next to the .musiclibrary bundle.  Instead we do a broader
    // multi-location search, including the Backups/ subfolder Music creates automatically.
    private nonisolated static func musicLibraryXMLURL() -> URL? {
        // All filenames Music has ever used for the XML export
        let candidateNames = [
            "Music Library.xml",
            "iTunes Library.xml",
            "Library.xml",           // found in Backups/
        ]
        let fm = FileManager.default

        // Helper: return the first candidate XML that exists in `dir`
        func first(in dir: URL) -> URL? {
            for name in candidateNames {
                let candidate = dir.appendingPathComponent(name)
                if fm.fileExists(atPath: candidate.path) { return candidate }
            }
            return nil
        }

        // 0. Check custom XML path persistently chosen by the user
        if let customPath = UserDefaults.standard.string(forKey: "customXMLPath") {
            let customURL = URL(fileURLWithPath: customPath)
            if fm.fileExists(atPath: customURL.path) { return customURL }
        }

        // 1. Read the library-url stored by Music.app in its preferences plist.
        //    The URL uses percent-encoding with Unicode decomposition (e.g. Mu%CC%81sica),
        //    so we must go through .path to get a filesystem-usable path.
        let prefsPath = NSHomeDirectory() + "/Library/Preferences/com.apple.Music.plist"
        if let prefsData = try? Data(contentsOf: URL(fileURLWithPath: prefsPath)),
           let prefs = try? PropertyListSerialization.propertyList(from: prefsData, format: nil) as? [String: Any],
           let rawURL = prefs["library-url"] as? String,
           let encodedURL = URL(string: rawURL) {

            // Convert the percent-encoded URL back to a real filesystem path
            let bundlePath = encodedURL.path          // e.g. /Users/.../Música/iTunes/Music Library.musiclibrary
            let bundleURL  = URL(fileURLWithPath: bundlePath)
            let parentDir  = bundleURL.deletingLastPathComponent()   // .../iTunes/

            // Check next to the bundle
            if let found = first(in: parentDir) { return found }

            // Check in Backups/ subfolder (Music writes here automatically)
            let backupsDir = parentDir.appendingPathComponent("Backups")
            if let found = first(in: backupsDir) { return found }

            // Also check one level up (edge case: library stored deeper)
            let grandparentDir = parentDir.deletingLastPathComponent()
            if let found = first(in: grandparentDir) { return found }
        }

        // 2. Fallback: standard ~/Music/Music/ location
        let defaultDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Music/Music")
        if let found = first(in: defaultDir) { return found }

        // 3. Fallback: ~/Music/iTunes/ (older setups)
        let itunesDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Music/iTunes")
        if let found = first(in: itunesDir) { return found }
        if let found = first(in: itunesDir.appendingPathComponent("Backups")) { return found }

        // 4. Fallback: broader user directories (~/Downloads, ~/Documents, ~/Desktop)
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        let searchDirs = [
            homeURL.appendingPathComponent("Downloads"),
            homeURL.appendingPathComponent("Documents"),
            homeURL.appendingPathComponent("Desktop")
        ]
        for dir in searchDirs {
            if let found = first(in: dir) { return found }
        }

        return nil
    }



    // MARK: - Load Stunning Offline Demo Library (Mock Data)

    func loadDemoLibrary() {
        let now = Date().timeIntervalSince1970
        let oneDay: Double = 86400
        let oneMonth: Double = 86400 * 30
        let oneYear: Double = 86400 * 365
        
        var mock: [Track] = []
        
        // Genre categories
        let synthwave = "Synthwave"
        let rock = "Indie Rock"
        let lofi = "Lofi House"
        let orchestral = "Orchestral"
        let jazz = "Dark Jazz"
        let pop = "Dreampop"
        
        // 1. Syntwave tracks
        mock.append(contentsOf: [
            Track(name: "Nightcall Glide", artist: "Kavinsky Grid", album: "Outrun Vibe", genre: synthwave, playCount: 324, skipCount: 2, rating: 100, dateAdded: now - (oneYear * 4), lastPlayed: now - (oneDay * 2), year: 2019),
            Track(name: "Neon Ridge", artist: "Laserhawk", album: "Redline", genre: synthwave, playCount: 289, skipCount: 4, rating: 100, dateAdded: now - (oneYear * 3.2), lastPlayed: now - (oneDay * 4), year: 2017),
            Track(name: "Cyber Sunset", artist: "FM-84", album: "Atlas", genre: synthwave, playCount: 182, skipCount: 12, rating: 80, dateAdded: now - (oneYear * 2.5), lastPlayed: now - (oneMonth * 3), year: 2016),
            Track(name: "Running in the Dark", artist: "The Midnight", album: "Endless Summer", genre: synthwave, playCount: 342, skipCount: 1, rating: 100, dateAdded: now - (oneYear * 3.8), lastPlayed: now - (oneDay * 1), year: 2016),
            Track(name: "Sunset Boulevard", artist: "The Midnight", album: "Nocturnal", genre: synthwave, playCount: 205, skipCount: 6, rating: 90, dateAdded: now - (oneYear * 2.8), lastPlayed: now - (oneMonth * 1), year: 2017),
            Track(name: "Grid Crawler", artist: "Timecop1983", album: "Night Drive", genre: synthwave, playCount: 142, skipCount: 18, rating: 60, dateAdded: now - (oneYear * 2.1), lastPlayed: now - (oneMonth * 4), year: 2018),
            Track(name: "Vector Run", artist: "Waveshaper", album: "Station Nova", genre: synthwave, playCount: 98, skipCount: 22, rating: 40, dateAdded: now - (oneYear * 1.8), lastPlayed: now - (oneMonth * 8), year: 2015)
        ])
        
        // 2. Indie Rock tracks
        mock.append(contentsOf: [
            Track(name: "Breezeblocks", artist: "Alt-J", album: "An Awesome Wave", genre: rock, playCount: 212, skipCount: 24, rating: 100, dateAdded: now - (oneYear * 4.5), lastPlayed: now - (oneDay * 12), year: 2012),
            Track(name: "Fake Tales of San Francisco", artist: "Arctic Monkeys", album: "Whatever People Say I Am", genre: rock, playCount: 310, skipCount: 5, rating: 100, dateAdded: now - (oneYear * 5.0), lastPlayed: now - (oneDay * 5), year: 2006),
            Track(name: "Reptilia", artist: "The Strokes", album: "Room on Fire", genre: rock, playCount: 290, skipCount: 8, rating: 100, dateAdded: now - (oneYear * 4.8), lastPlayed: now - (oneDay * 1), year: 2003),
            Track(name: "Under Cover of Darkness", artist: "The Strokes", album: "Angles", genre: rock, playCount: 194, skipCount: 15, rating: 80, dateAdded: now - (oneYear * 3.5), lastPlayed: now - (oneMonth * 2), year: 2011),
            Track(name: "Myth", artist: "Beach House", album: "Bloom", genre: rock, playCount: 224, skipCount: 11, rating: 100, dateAdded: now - (oneYear * 4.2), lastPlayed: now - (oneMonth * 1), year: 2012),
            Track(name: "Lost in the Dream", artist: "The War on Drugs", album: "Lost in the Dream", genre: rock, playCount: 150, skipCount: 25, rating: 80, dateAdded: now - (oneYear * 3.0), lastPlayed: now - (oneMonth * 5), year: 2014),
            Track(name: "Red Eyes", artist: "The War on Drugs", album: "Lost in the Dream", genre: rock, playCount: 165, skipCount: 14, rating: 80, dateAdded: now - (oneYear * 2.9), lastPlayed: now - (oneMonth * 3), year: 2014),
            // Forgotten gems in Rock (Rated 4-5 stars, not played in 2+ years)
            Track(name: "Float On", artist: "Modest Mouse", album: "Good News for People Who Love Bad News", genre: rock, playCount: 140, skipCount: 30, rating: 100, dateAdded: now - (oneYear * 4.8), lastPlayed: now - (oneYear * 2.4), year: 2004),
            Track(name: "Obstacle 1", artist: "Interpol", album: "Turn on the Bright Lights", genre: rock, playCount: 115, skipCount: 35, rating: 80, dateAdded: now - (oneYear * 4.2), lastPlayed: now - (oneYear * 2.8), year: 2002)
        ])
        
        // 3. Lofi House tracks
        mock.append(contentsOf: [
            Track(name: "Winona", artist: "DJ Boring", album: "Winona EP", genre: lofi, playCount: 254, skipCount: 3, rating: 100, dateAdded: now - (oneYear * 2.9), lastPlayed: now - (oneDay * 3), year: 2016),
            Track(name: "Baby, I'm Lonely", artist: "Baltic Sound", album: "Deep Baltic", genre: lofi, playCount: 210, skipCount: 8, rating: 90, dateAdded: now - (oneYear * 2.2), lastPlayed: now - (oneDay * 7), year: 2018),
            Track(name: "Never Lived Alonely", artist: "Ross from Friends", album: "Family Portrait", genre: lofi, playCount: 188, skipCount: 14, rating: 80, dateAdded: now - (oneYear * 2.0), lastPlayed: now - (oneMonth * 2), year: 2018),
            Track(name: "Talk To Me", artist: "Mall Grab", album: "Sun Palace", genre: lofi, playCount: 230, skipCount: 5, rating: 100, dateAdded: now - (oneYear * 2.6), lastPlayed: now - (oneDay * 1), year: 2017),
            Track(name: "U", artist: "Tourist", album: "U", genre: lofi, playCount: 165, skipCount: 20, rating: 80, dateAdded: now - (oneYear * 3.1), lastPlayed: now - (oneMonth * 4), year: 2016)
        ])
        
        // 4. Orchestral / Soundtracks
        mock.append(contentsOf: [
            Track(name: "Time", artist: "Hans Zimmer", album: "Inception OST", genre: orchestral, playCount: 275, skipCount: 1, rating: 100, dateAdded: now - (oneYear * 4.9), lastPlayed: now - (oneDay * 10), year: 2010),
            Track(name: "Cornfield Chase", artist: "Hans Zimmer", album: "Interstellar OST", genre: orchestral, playCount: 305, skipCount: 2, rating: 100, dateAdded: now - (oneYear * 4.6), lastPlayed: now - (oneDay * 2), year: 2014),
            Track(name: "Experience", artist: "Ludovico Einaudi", album: "In a Time Lapse", genre: orchestral, playCount: 198, skipCount: 10, rating: 90, dateAdded: now - (oneYear * 3.0), lastPlayed: now - (oneMonth * 1), year: 2013),
            Track(name: "Nuvole Bianche", artist: "Ludovico Einaudi", album: "Una Mattina", genre: orchestral, playCount: 160, skipCount: 18, rating: 80, dateAdded: now - (oneYear * 3.5), lastPlayed: now - (oneMonth * 3), year: 2004),
            Track(name: "First Step", artist: "Hans Zimmer", album: "Interstellar OST", genre: orchestral, playCount: 240, skipCount: 3, rating: 100, dateAdded: now - (oneYear * 4.4), lastPlayed: now - (oneDay * 15), year: 2014),
            // Forgotten Gems in Orchestral (Rated 4-5 stars, not played in 2+ years)
            Track(name: "Arrival of the Birds", artist: "The Cinematic Orchestra", album: "The Crimson Wing", genre: orchestral, playCount: 135, skipCount: 12, rating: 100, dateAdded: now - (oneYear * 4.5), lastPlayed: now - (oneYear * 3.0), year: 2008),
            Track(name: "Lux Aeterna", artist: "Clint Mansell", album: "Requiem for a Dream", genre: orchestral, playCount: 95, skipCount: 40, rating: 80, dateAdded: now - (oneYear * 4.0), lastPlayed: now - (oneYear * 2.6), year: 2000)
        ])
        
        // 5. Dark Jazz
        mock.append(contentsOf: [
            Track(name: "All That Jazz", artist: "Miles Davis", album: "Kind of Blue", genre: jazz, playCount: 208, skipCount: 9, rating: 100, dateAdded: now - (oneYear * 5.0), lastPlayed: now - (oneDay * 9), year: 1959),
            Track(name: "Blue in Green", artist: "Miles Davis", album: "Kind of Blue", genre: jazz, playCount: 172, skipCount: 10, rating: 100, dateAdded: now - (oneYear * 4.9), lastPlayed: now - (oneDay * 14), year: 1959),
            Track(name: "Take Five", artist: "Dave Brubeck Quartet", album: "Time Out", genre: jazz, playCount: 185, skipCount: 15, rating: 80, dateAdded: now - (oneYear * 4.8), lastPlayed: now - (oneMonth * 1), year: 1959),
            Track(name: "My Funny Valentine", artist: "Chet Baker", album: "Chet Baker Sings", genre: jazz, playCount: 220, skipCount: 6, rating: 100, dateAdded: now - (oneYear * 4.1), lastPlayed: now - (oneDay * 6), year: 1954),
            Track(name: "Strasbourg / St. Denis", artist: "Roy Hargrove", album: "Earfood", genre: jazz, playCount: 155, skipCount: 19, rating: 80, dateAdded: now - (oneYear * 3.2), lastPlayed: now - (oneMonth * 2), year: 2008),
            // Forgotten Gems in Jazz (Rated 4-5 stars, not played in 2+ years)
            Track(name: "So What", artist: "Miles Davis", album: "Kind of Blue", genre: jazz, playCount: 150, skipCount: 20, rating: 100, dateAdded: now - (oneYear * 5.0), lastPlayed: now - (oneYear * 2.2), year: 1959),
            Track(name: "Round Midnight", artist: "Thelonious Monk", album: "Thelonious Himself", genre: jazz, playCount: 88, skipCount: 25, rating: 80, dateAdded: now - (oneYear * 4.6), lastPlayed: now - (oneYear * 3.1), year: 1957)
        ])
        
        // 6. Dreampop / Shoegaze
        mock.append(contentsOf: [
            Track(name: "Cherry-coloured Funk", artist: "Cocteau Twins", album: "Heaven or Las Vegas", genre: pop, playCount: 245, skipCount: 4, rating: 100, dateAdded: now - (oneYear * 4.0), lastPlayed: now - (oneDay * 2), year: 1990),
            Track(name: "Heaven or Las Vegas", artist: "Cocteau Twins", album: "Heaven or Las Vegas", genre: pop, playCount: 280, skipCount: 3, rating: 100, dateAdded: now - (oneYear * 3.9), lastPlayed: now - (oneDay * 8), year: 1990),
            Track(name: "Only Shallow", artist: "My Bloody Valentine", album: "Loveless", genre: pop, playCount: 162, skipCount: 30, rating: 80, dateAdded: now - (oneYear * 3.7), lastPlayed: now - (oneMonth * 4), year: 1991),
            Track(name: "Alison", artist: "Slowdive", album: "Souvlaki", genre: pop, playCount: 234, skipCount: 7, rating: 100, dateAdded: now - (oneYear * 3.8), lastPlayed: now - (oneDay * 5), year: 1993),
            Track(name: "When the Sun Hits", artist: "Slowdive", album: "Souvlaki", genre: pop, playCount: 250, skipCount: 2, rating: 100, dateAdded: now - (oneYear * 3.8), lastPlayed: now - (oneDay * 4), year: 1993),
            Track(name: "Space Song", artist: "Beach House", album: "Depression Cherry", genre: pop, playCount: 315, skipCount: 5, rating: 100, dateAdded: now - (oneYear * 3.2), lastPlayed: now - (oneDay * 1), year: 2015),
            Track(name: "Lazuli", artist: "Beach House", album: "Bloom", genre: pop, playCount: 190, skipCount: 12, rating: 80, dateAdded: now - (oneYear * 3.1), lastPlayed: now - (oneMonth * 1), year: 2012)
        ])
        
        // 7. "Song Fatigue" and "Disliked" tracks for behavioral analysis
        // Song Fatigue: High play count, but recently skipped heavily or high skip count
        mock.append(contentsOf: [
            Track(name: "Overplayed Anthem", artist: "Pop Starlet", album: "Radio Hits", genre: pop, playCount: 280, skipCount: 78, rating: 40, dateAdded: now - (oneYear * 2.0), lastPlayed: now - (oneMonth * 1), year: 2021),
            Track(name: "Repetitive Beat", artist: "Club DJ", album: "Club Mix Vol 4", genre: lofi, playCount: 210, skipCount: 95, rating: 20, dateAdded: now - (oneYear * 1.5), lastPlayed: now - (oneMonth * 2), year: 2022)
        ])
        // Unpopular/Skipped immediately: Low plays, high skips
        mock.append(contentsOf: [
            Track(name: "Instant Skip", artist: " экспериментальный", album: "Noise Experiments", genre: rock, playCount: 2, skipCount: 42, rating: 0, dateAdded: now - (oneYear * 1.1), lastPlayed: now - (oneMonth * 6), year: 2023),
            Track(name: "Wrong Recommendation", artist: "Generic Sound", album: "Boring Album", genre: synthwave, playCount: 4, skipCount: 35, rating: 20, dateAdded: now - (oneYear * 0.8), lastPlayed: now - (oneMonth * 5), year: 2024)
        ])
        
        // Add library growth over time
        // Loop to insert older, middle, and newer songs to simulate timeline growth over past years
        let cal = Calendar.current
        let currentDate = cal.date(byAdding: .year, value: -5, to: Date()) ?? Date()
        for yearIdx in 0..<5 {
            for monthIdx in 1...12 {
                let addedTimestamp = cal.date(byAdding: .month, value: (yearIdx * 12) + monthIdx, to: currentDate)?.timeIntervalSince1970 ?? now
                let countOfTracks = Int.random(in: 1...3)
                for i in 0..<countOfTracks {
                    let mockTrack = Track(
                        name: "Archive Track #\(yearIdx * 12 + monthIdx)-\(i)",
                        artist: "Archive Ensemble",
                        album: "The Vault Collection",
                        genre: ["Synthwave", "Indie Rock", "Dreampop", "Lofi House", "Orchestral", "Dark Jazz"].randomElement()!,
                        playCount: Int.random(in: 15...120),
                        skipCount: Int.random(in: 0...10),
                        rating: [60, 80, 100].randomElement()!,
                        dateAdded: addedTimestamp,
                        lastPlayed: now - Double.random(in: oneDay...oneMonth),
                        year: 2010 + (yearIdx * 3)
                    )
                    mock.append(mockTrack)
                }
            }
        }
        
        self.tracks = mock
    }
    
    // MARK: - Analytics Computations (For Swift Charts and UI KPIs)
    
    var totalTracks: Int {
        return tracks.count
    }
    
    // Estimates total listening time based on play count
    // Assumes an average track length of 3.5 minutes (210 seconds)
    var totalListeningTimeInSeconds: Double {
        let averageTrackLength: Double = 210 // 3.5 minutes
        return tracks.reduce(0.0) { $0 + (Double($1.playCount) * averageTrackLength) }
    }
    
    var totalListeningTimeFormatted: String {
        let seconds = totalListeningTimeInSeconds
        let days = Int(seconds / 86400)
        let hours = Int((seconds.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var topArtist: String {
        guard !tracks.isEmpty else { return "No Music" }
        // Sum playcount per artist
        var artistPlays: [String: Int] = [:]
        for track in tracks {
            artistPlays[track.artist, default: 0] += track.playCount
        }
        return artistPlays.max(by: { $0.value < $1.value })?.key ?? "Unknown"
    }
    
    var topGenre: String {
        guard !tracks.isEmpty else { return "No Music" }
        var genreCounts: [String: Int] = [:]
        for track in tracks {
            genreCounts[track.genre, default: 0] += 1
        }
        return genreCounts.max(by: { $0.value < $1.value })?.key ?? "Unknown"
    }
    
    // Genre Distribution
    var genreDistribution: [GenreStat] {
        let total = Double(tracks.count)
        guard total > 0 else { return [] }
        
        var counts: [String: Int] = [:]
        for track in tracks {
            counts[track.genre, default: 0] += 1
        }
        
        return counts.map { genre, count in
            GenreStat(genre: genre, count: count, percentage: (Double(count) / total) * 100)
        }.sorted(by: { $0.count > $1.count })
    }
    
    // Forgotten Gems (Rated 4-5 stars, not played in over 2 years)
    var forgottenGems: [Track] {
        let twoYearsAgo = Date().addingTimeInterval(-2 * 365 * 86400)
        
        // Try filtering by explicit rating first (>= 4 stars / 80 rating)
        var candidates = tracks.filter { track in
            guard track.rating >= 80 else { return false }
            
            if let lastPlayed = track.lastPlayedDate {
                return lastPlayed < twoYearsAgo
            } else if let added = track.addedDate {
                return added < twoYearsAgo
            }
            return false
        }
        
        // Fallback: If no rated gems, use high play counts (plays >= 12 or plays in top 15%)
        if candidates.count < 3 {
            let plays = tracks.map(\.playCount)
            let maxPlay = plays.max() ?? 0
            let playThreshold = max(10, maxPlay / 5)
            
            candidates = tracks.filter { track in
                guard track.playCount >= playThreshold else { return false }
                
                if let lastPlayed = track.lastPlayedDate {
                    return lastPlayed < twoYearsAgo
                } else if let added = track.addedDate {
                    return added < twoYearsAgo
                }
                return false
            }
        }
        
        return candidates.sorted(by: { ($0.lastPlayedDate ?? Date.distantPast) < ($1.lastPlayedDate ?? Date.distantPast) })
    }
    
    // Timeline of Tracks Added (by month/year)
    var tracksAddedTimeline: [TimelineStat] {
        let cal = Calendar.current
        var groupings: [String: (date: Date, count: Int)] = [:]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        for track in tracks {
            guard let addedDate = track.addedDate else { continue }
            // Find the start of the month to group dates cleanly
            let components = cal.dateComponents([.year, .month], from: addedDate)
            guard let monthStart = cal.date(from: components) else { continue }
            
            let key = formatter.string(from: monthStart)
            if let existing = groupings[key] {
                groupings[key] = (monthStart, existing.count + 1)
            } else {
                groupings[key] = (monthStart, 1)
            }
        }
        
        return groupings.values.map { val in
            TimelineStat(date: val.date, monthYearString: formatter.string(from: val.date), count: val.count)
        }.sorted(by: { $0.date < $1.date })
    }
    
    // Cumulative Library Growth Timeline
    var cumulativeTracksAddedTimeline: [TimelineStat] {
        let monthly = tracksAddedTimeline
        var runningTotal = 0
        return monthly.map { stat in
            runningTotal += stat.count
            return TimelineStat(date: stat.date, monthYearString: stat.monthYearString, count: runningTotal)
        }
    }
    
    // Era Distribution (Breakdown by Release Year)
    var eraDistribution: [YearStat] {
        var groups: [String: Int] = [:]
        
        for track in tracks {
            let year = track.year
            guard year > 0 else { continue }
            
            let era: String
            if year < 1970 {
                era = "Pre-70s"
            } else if year < 1980 {
                era = "70s"
            } else if year < 1990 {
                era = "80s"
            } else if year < 2000 {
                era = "90s"
            } else if year < 2010 {
                era = "00s"
            } else if year < 2020 {
                era = "10s"
            } else {
                era = "20s"
            }
            
            groups[era, default: 0] += 1
        }
        
        let orderedEras = ["Pre-70s", "70s", "80s", "90s", "00s", "10s", "20s"]
        return orderedEras.compactMap { era in
            guard let count = groups[era] else { return nil }
            return YearStat(era: era, count: count)
        }
    }
}
