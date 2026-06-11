import Foundation
import SwiftUI
import CoreLocation
import MapKit

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
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown Track"
        self.artist = (try? container.decode(String.self, forKey: .artist)) ?? "Unknown Artist"
        self.album = (try? container.decode(String.self, forKey: .album)) ?? "Unknown Album"
        self.genre = (try? container.decode(String.self, forKey: .genre)) ?? "Unknown Genre"
        
        self.playCount = (try? container.decode(Int.self, forKey: .playCount)) ??
                         (try? container.decode(Double.self, forKey: .playCount)).map(Int.init) ?? 0
                         
        self.skipCount = (try? container.decode(Int.self, forKey: .skipCount)) ??
                         (try? container.decode(Double.self, forKey: .skipCount)).map(Int.init) ?? 0
                         
        self.rating = (try? container.decode(Int.self, forKey: .rating)) ??
                      (try? container.decode(Double.self, forKey: .rating)).map(Int.init) ?? 0
                      
        self.dateAdded = try? container.decode(Double.self, forKey: .dateAdded)
        self.lastPlayed = try? container.decode(Double.self, forKey: .lastPlayed)
        
        self.year = (try? container.decode(Int.self, forKey: .year)) ??
                    (try? container.decode(Double.self, forKey: .year)).map(Int.init) ?? 0
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

// MARK: - Photo Model
struct Photo: Codable, Identifiable, Hashable {
    let id: String
    let filename: String
    let dateAdded: Double // Unix Timestamp
    let latitude: Double?
    let longitude: Double?
    var altitude: Double?
    let width: Int
    let height: Int
    let isFavorite: Bool
    
    // Geocoded Place Info (Mutable for background geocoding updates)
    var cityName: String?
    var countryName: String?
    
    // Additional Properties
    let isLivePhoto: Bool
    var cameraModel: String?
    
    enum CodingKeys: String, CodingKey {
        case id, filename, dateAdded, latitude, longitude, altitude, width, height, isFavorite, cityName, countryName, isLivePhoto, cameraModel
    }
    
    init(id: String, filename: String, dateAdded: Double, latitude: Double?, longitude: Double?, altitude: Double?, width: Int, height: Int, isFavorite: Bool, cityName: String? = nil, countryName: String? = nil, isLivePhoto: Bool = false, cameraModel: String? = nil) {
        self.id = id
        self.filename = filename
        self.dateAdded = dateAdded
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.width = width
        self.height = height
        self.isFavorite = isFavorite
        self.cityName = cityName
        self.countryName = countryName
        self.isLivePhoto = isLivePhoto
        self.cameraModel = cameraModel
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        filename = try container.decode(String.self, forKey: .filename)
        dateAdded = try container.decode(Double.self, forKey: .dateAdded)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        cityName = try container.decodeIfPresent(String.self, forKey: .cityName)
        countryName = try container.decodeIfPresent(String.self, forKey: .countryName)
        isLivePhoto = try container.decodeIfPresent(Bool.self, forKey: .isLivePhoto) ?? false
        cameraModel = try container.decodeIfPresent(String.self, forKey: .cameraModel)
    }
    
    // Custom Computed Metadata
    var mediaType: String {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        if ["mov", "mp4", "m4v", "avi", "3gp"].contains(ext) {
            return "Video"
        }
        return "Photo"
    }
    
    var aspectCategory: String {
        guard width > 0 && height > 0 else { return "Unknown" }
        let ratio = Double(width) / Double(height)
        if abs(ratio - 1.0) < 0.05 {
            return "Square (1:1)"
        } else if ratio > 2.0 {
            return "Panoramic"
        } else if ratio > 1.0 {
            return "Landscape"
        } else {
            return "Portrait"
        }
    }
    
    var capturedDate: Date {
        return Date(timeIntervalSince1970: dateAdded)
    }
}

// MARK: - Mapped Cluster Model
struct MappedCluster: Identifiable, Equatable {
    let id: String // City, Country or formatted Coordinate
    let cityName: String
    let countryName: String
    let coordinate: CLLocationCoordinate2D
    let photos: [Photo]
    
    var count: Int { photos.count }
    
    var photoCount: Int {
        photos.filter { $0.mediaType == "Photo" }.count
    }
    
    var videoCount: Int {
        photos.filter { $0.mediaType == "Video" }.count
    }
    
    var camerasUsed: [String] {
        let models = photos.compactMap { $0.cameraModel }
        return Array(Set(models)).sorted()
    }
    
    var dateRangeFormatted: String {
        guard !photos.isEmpty else { return "No date" }
        let dates = photos.map(\.dateAdded)
        let minDate = Date(timeIntervalSince1970: dates.min() ?? 0)
        let maxDate = Date(timeIntervalSince1970: dates.max() ?? 0)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        // If same day
        if Calendar.current.isDate(minDate, inSameDayAs: maxDate) {
            return formatter.string(from: minDate)
        }
        
        return "\(formatter.string(from: minDate)) – \(formatter.string(from: maxDate))"
    }
    
    static func == (lhs: MappedCluster, rhs: MappedCluster) -> Bool {
        lhs.id == rhs.id && lhs.count == rhs.count
    }
}

// MARK: - Map Zoom Level Enum
enum MapZoomLevel: Int, CaseIterable, Codable {
    case world
    case continent
    case regional
    case city
    case neighborhood
    case street
    
    static func level(forDelta delta: Double) -> MapZoomLevel {
        if delta > 40.0 { return .world }
        if delta > 8.0 { return .continent }
        if delta > 2.0 { return .regional }
        if delta > 0.4 { return .city }
        if delta > 0.08 { return .neighborhood }
        return .street
    }
    
    var representativeDelta: Double {
        switch self {
        case .world: return 50.0
        case .continent: return 15.0
        case .regional: return 5.0
        case .city: return 1.0
        case .neighborhood: return 0.2
        case .street: return 0.01
        }
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

struct PhotoTimelineStat: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let monthYearString: String
    let count: Int
}

struct CameraStat: Identifiable, Hashable {
    let id = UUID()
    let camera: String
    let count: Int
}

struct AspectRatioStat: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let count: Int
    let percentage: Double
}

struct DestinationStat: Identifiable, Hashable {
    let id = UUID()
    let city: String
    let country: String
    let count: Int
}

struct AltitudeBucket: Identifiable, Hashable {
    let id = UUID()
    let label: String // e.g., "Sea Level", "Low Elevation", "High Mountains"
    let count: Int
}

struct HistogramDataPoint: Identifiable, Hashable {
    let id = UUID()
    let intKey: Int
    let label: String
    let count: Int
    let type: String // "Photo" or "Video"
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
    
    var totalListeningTimeFormatted: String {
        let seconds = Double(totalPlays) * 210.0 // 3.5 minutes average track length
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

// MARK: - Photos Precomputed Analytics Structure
struct PhotosAnalytics {
    let totalAssetsCount: Int
    let favoritesCount: Int
    let favoritePercentage: Double
    let videosCount: Int
    let photosCount: Int
    let dateRangeFormatted: String
    let mediaTypeComposition: [GenreStat]
    let photosTimeline: [TimelineStat]
    let captureHourCounts: [Int: Int]
    let hourlyHistogramData: [HistogramDataPoint]
    let weekdayHistogramData: [HistogramDataPoint]
    let dayOfMonthHistogramData: [HistogramDataPoint]
    let monthHistogramData: [HistogramDataPoint]
    let peakWeekday: String
    let peakWeekdayPercentage: Double
    let temporalCaptureStats: [TemporalStat]
    let cameraDistribution: [CameraStat]
    let aspectRatios: [AspectRatioStat]
    let destinations: [DestinationStat]
    let totalCitiesVisited: Int
    let totalCountriesVisited: Int
    let maxAltitudePhoto: Photo?
    let maxAltitudeFormatted: String
    let maxAltitudeDetails: String
    let maxAltitude: Double
    let northernMostPhoto: Photo?
    let southernMostPhoto: Photo?
    let northernMostFormatted: String
    let northernMostDetails: String
    let southernMostFormatted: String
    let southernMostDetails: String
    let altitudeProfile: [AltitudeBucket]
    let photographyPersona: PersonaProfile
    
    // Precomputed map and sidebar clusters
    let cityClusters: [MappedCluster]
    let countryClusters: [MappedCluster]
    let mapClustersByZoomLevel: [MapZoomLevel: [MappedCluster]]
}

// MARK: - Music Precomputed Analytics Structure
struct MusicAnalytics {
    let totalTracks: Int
    let totalListeningTimeInSeconds: Double
    let totalListeningTimeFormatted: String
    let topArtist: String
    let topArtistListeningTimeFormatted: String
    let topGenre: String
    let genreDistribution: [GenreStat]
    let forgottenGems: [Track]
    let loveHateParadox: [Track]
    let listeningHourCounts: [Int: Int]
    let temporalStats: [TemporalStat]
    let tracksAddedTimeline: [TimelineStat]
    let cumulativeTracksAddedTimeline: [TimelineStat]
    let eraDistribution: [YearStat]
    let topArtistsDetailed: [ArtistStat]
    let listeningPersona: PersonaProfile
}



