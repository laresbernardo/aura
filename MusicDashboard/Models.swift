import Foundation
import SwiftUI

// MARK: - Track Model
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
        self.name = try container.decode(String.self, forKey: .name)
        self.artist = try container.decode(String.self, forKey: .artist)
        self.album = try container.decode(String.self, forKey: .album)
        self.genre = try container.decode(String.self, forKey: .genre)
        self.playCount = try container.decode(Int.self, forKey: .playCount)
        self.skipCount = try container.decode(Int.self, forKey: .skipCount)
        self.rating = try container.decode(Int.self, forKey: .rating)
        self.dateAdded = try container.decodeIfPresent(Double.self, forKey: .dateAdded)
        self.lastPlayed = try container.decodeIfPresent(Double.self, forKey: .lastPlayed)
        self.year = try container.decode(Int.self, forKey: .year)
    }
    
    // Direct initializer for mock data and tests
    init(id: UUID = UUID(), name: String, artist: String, album: String, genre: String, playCount: Int, skipCount: Int, rating: Int, dateAdded: Double?, lastPlayed: Double?, year: Int) {
        self.id = id
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
    
    // Helper computations
    var ratingStars: Int {
        return Int(round(Double(rating) / 20.0))
    }
    
    var addedDate: Date? {
        guard let timestamp = dateAdded else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    var lastPlayedDate: Date? {
        guard let timestamp = lastPlayed else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

// MARK: - Chart Data Models
struct GenreStat: Identifiable, Hashable {
    let id = UUID()
    let genre: String
    let count: Int
    let percentage: Double
}

struct YearStat: Identifiable, Hashable {
    let id = UUID()
    let era: String // e.g., "1990s", "2000s", "2020s"
    let count: Int
}

struct TimelineStat: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let monthYearString: String // e.g., "Jan 2025"
    let count: Int
}

// MARK: - Advanced Analytics Models

struct ArtistStat: Identifiable, Hashable {
    let id = UUID()
    let artist: String
    let trackCount: Int
    let totalPlays: Int
    let averagePlaysPerTrack: Double
    let totalSkips: Int
    let engagementScore: Double // (plays / (plays + skips)) * 100
}

struct PersonaProfile: Hashable {
    let name: String
    let subtitle: String
    let description: String
    let nostalgiaIndex: Double // 0-100
    let varietyScore: Double // 0-100
    let focusScore: Double // 0-100
    let loyaltyScore: Double // 0-100 (plays vs skips ratio)
    let gradientColors: [Color] // Colors for dynamic glowing persona card
}

struct TemporalStat: Identifiable, Hashable {
    let id: UUID
    let period: String // "Morning Birds", "Afternoon Focus", "Sunset Chill", "Midnight Owls"
    let count: Int
    let description: String
    let icon: String
    let gradientColors: [Color]
    
    init(id: UUID = UUID(), period: String, count: Int, description: String, icon: String, gradientColors: [Color]) {
        self.id = id
        self.period = period
        self.count = count
        self.description = description
        self.icon = icon
        self.gradientColors = gradientColors
    }
}

// MARK: - Time Filtering Models
enum TimeFilter: Hashable, Identifiable {
    case allTime
    case specificYear(Int)
    case customRange
    
    var id: String {
        switch self {
        case .allTime: return "allTime"
        case .specificYear(let y): return "year-\(y)"
        case .customRange: return "customRange"
        }
    }
}


