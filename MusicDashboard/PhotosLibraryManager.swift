import Foundation
import SwiftUI
import Combine
import AppKit
import CoreLocation
import Photos

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

// MARK: - Chart & Analytics Models for Photos
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

// MARK: - Photos Library Manager
@MainActor
class PhotosLibraryManager: ObservableObject {
    enum SourceMode: String, CaseIterable, Identifiable {
        case demo = "Demo Mode"
        case direct = "Direct Sync"
        
        var id: String { rawValue }
    }
    
    enum PhotosAppState {
        case unknown
        case running
        case notRunning
        case permissionDenied
    }
    
    @Published var photos: [Photo] = []
    @Published var allPhotos: [Photo] = []
    @Published var isLoading: Bool = false
    @Published var syncError: String? = nil
    @Published var syncStatus: String = ""
    @Published var isGeocoding: Bool = false
    @Published var sourceMode: SourceMode = .demo
    @Published var photosAppRunningState: PhotosAppState = .unknown
    
    @Published var currentFilter: TimeFilter = .specificYear(Calendar.current.component(.year, from: Date()))
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var customEndDate: Date = Date()
    
    var currentYearString: String {
        "\(Calendar.current.component(.year, from: Date()))"
    }
    var previousYearString: String {
        "\(Calendar.current.component(.year, from: Date()) - 1)"
    }
    var twoYearsAgoString: String {
        "\(Calendar.current.component(.year, from: Date()) - 2)"
    }
    
    private var geocodeTask: Task<Void, Never>? = nil
    
    private var cacheURL: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Aura", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir.appendingPathComponent("photos_cache_v2.json")
    }
    
    private func loadCachedPhotos() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheURL)
            var cached = try JSONDecoder().decode([Photo].self, from: data)
            
            // Clean altitudes to ensure only valid land-level elevations are cataloged
            for idx in 0..<cached.count {
                if let alt = cached[idx].altitude {
                    if abs(alt) < 0.01 || alt < -100.0 || alt > 8500.0 {
                        cached[idx].altitude = nil
                    }
                }
            }
            
            if !cached.isEmpty {
                self.allPhotos = cached
                self.applyFilter()
            }
        } catch {
            // Silently fall back if the cache is corrupt or missing
        }
    }
    
    func savePhotosToCache() {
        do {
            let data = try JSONEncoder().encode(allPhotos)
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            // Silently ignore save errors
        }
    }

    init() {
        loadCachedPhotos()
        if allPhotos.isEmpty {
            loadDemoLibrary()
        }
    }
    
    var availableYears: [Int] {
        let cal = Calendar.current
        let years = allPhotos.map { item -> Int in
            cal.component(.year, from: item.capturedDate)
        }
        return Array(Set(years)).sorted(by: >)
    }
    
    func applyFilter() {
        let cal = Calendar.current
        
        switch currentFilter {
        case .allTime:
            self.photos = allPhotos
        case .specificYear(let targetYear):
            self.photos = allPhotos.filter { item in
                let year = cal.component(.year, from: item.capturedDate)
                return year == targetYear
            }
        case .customRange:
            let startOfDay = cal.startOfDay(for: customStartDate)
            let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
            
            self.photos = allPhotos.filter { item in
                let date = item.capturedDate
                return date >= startOfDay && date <= endOfDay
            }
        }
    }
    
    // Switch between library sources
    func changeSourceMode(to newMode: SourceMode) {
        // Cancel active geocoding task when switching
        geocodeTask?.cancel()
        
        sourceMode = newMode
        syncError = nil
        
        switch newMode {
        case .demo:
            loadDemoLibrary()
        case .direct:
            loadCachedPhotos()
            if allPhotos.isEmpty {
                self.photos = []
            }
            Task { await fetchDirectLibrary() }
        }
    }
    
    // Sidebar dynamic information
    var sourceModeDescription: String {
        switch sourceMode {
        case .demo: return "Stunning Offline Preview Mode"
        case .direct: return "Communicating directly with Photos.app"
        }
    }
    
    var sourceModeColor: Color {
        switch sourceMode {
        case .demo: return .purple
        case .direct: return .emerald
        }
    }
    
    // Open Photos app
    func launchPhotosApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Photos"]
        try? process.run()
    }
    
    // MARK: - Direct Apple Photos Connection (JXA Engine)
    
    func fetchDirectLibrary(forceLaunch: Bool = false) async {
        self.isLoading = true
        self.syncError = nil
        self.syncStatus = "Requesting access to Photo Library..."
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            self.photosAppRunningState = .permissionDenied
            self.syncError = "Photo Library access was denied. Please enable it in System Settings → Privacy & Security → Photos."
            self.photos = []
            self.syncStatus = ""
            self.isLoading = false
            return
        }
        
        self.photosAppRunningState = .running
        self.syncStatus = "Fetching assets from PhotoKit..."
        
        let fetchResult = await Task.detached(priority: .userInitiated) { () -> PHFetchResult<PHAsset> in
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            // Cap at a highly responsive 100,000 photos to capture the user's entire library of 64,654 items
            options.fetchLimit = 100000
            return PHAsset.fetchAssets(with: options)
        }.value
        
        self.syncStatus = "Analyzing Photo Library captures..."
        
        let manager = self
        let fetchedPhotos = await Task.detached(priority: .userInitiated) { [manager] () -> [Photo] in
            var list: [Photo] = []
            let total = fetchResult.count
            list.reserveCapacity(total)
            
            fetchResult.enumerateObjects { (asset, index, stop) in
                let id = asset.localIdentifier
                
                // Super safe exception-guarded filename lookup using responds(to:)
                var filename = "IMG_\(index).jpg"
                if asset.responds(to: Selector(("filename"))) {
                    if let name = asset.value(forKey: "filename") as? String {
                        filename = name
                    }
                }
                
                let dateAdded = asset.creationDate?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
                let isFavorite = asset.isFavorite
                
                let latitude = asset.location?.coordinate.latitude
                let longitude = asset.location?.coordinate.longitude
                
                var altitude: Double? = nil
                if let loc = asset.location {
                    if loc.verticalAccuracy >= 0 {
                        let rawAlt = loc.altitude
                        if abs(rawAlt) > 0.01 && rawAlt >= -100.0 && rawAlt <= 8500.0 {
                            altitude = rawAlt
                        }
                    }
                }
                
                let width = asset.pixelWidth
                let height = asset.pixelHeight
                
                let photo = Photo(
                    id: id,
                    filename: filename,
                    dateAdded: dateAdded,
                    latitude: latitude,
                    longitude: longitude,
                    altitude: altitude,
                    width: width,
                    height: height,
                    isFavorite: isFavorite
                )
                list.append(photo)
                
                // Real-time progress updates to MainActor every 100 files
                if index % 100 == 0 || index == total - 1 {
                    Task { @MainActor in
                        manager.syncStatus = "Analyzing captures (\(index + 1) of \(total))..."
                    }
                }
            }
            return list
        }.value
        
        if fetchedPhotos.isEmpty {
            self.syncError = "Your Photos library appears to be empty."
            self.allPhotos = []
            self.photos = []
        } else {
            self.syncStatus = "Resolving locations & altitudes..."
            
            // Smart Merge: Restore already-geocoded cities/countries from memory/disk cache
            let existingMap = Dictionary(uniqueKeysWithValues: self.allPhotos.compactMap { photo -> (String, Photo)? in
                guard photo.cityName != nil else { return nil }
                return (photo.id, photo)
            })
            
            var merged: [Photo] = []
            merged.reserveCapacity(fetchedPhotos.count)
            for var p in fetchedPhotos {
                if let cached = existingMap[p.id] {
                    p.cityName = cached.cityName
                    p.countryName = cached.countryName
                }
                merged.append(p)
            }
            
            self.allPhotos = merged
            self.applyFilter()
            self.savePhotosToCache()
            self.syncError = nil
            
            // Trigger asynchronous geocoding for coordinates
            startGeocoding()
        }
        
        self.syncStatus = ""
        self.isLoading = false
    }
    
    private func checkIsPhotosAppRunning() async -> Bool {
        let checkScript = "Application('Photos').running()"
        let result = await runOsaScript(checkScript)
        switch result {
        case .success(let val):
            return val.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        case .failure:
            return false
        }
    }
    
    private func runOsaScript(_ script: String) async -> Result<String, Error> {
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", script]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let status = process.terminationStatus
                if status == 0 {
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        return .success(output)
                    } else {
                        return .failure(NSError(domain: "OsaScriptError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read string output."]))
                    }
                } else {
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errString = String(data: errData, encoding: .utf8) ?? "Unknown JXA error"
                    return .failure(NSError(domain: "OsaScriptError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: errString]))
                }
            } catch {
                return .failure(error)
            }
        }.value
    }
    
    // MARK: - CoreLocation Geocoding Engine
    
    var pendingGeocodeCount: Int {
        allPhotos.filter { $0.latitude != nil && $0.cityName == nil }.count
    }
    
    private func startGeocoding() {
        geocodeTask?.cancel()
        isGeocoding = true
        
        let manager = self
        geocodeTask = Task {
            defer {
                Task { @MainActor in
                    manager.isGeocoding = false
                    manager.savePhotosToCache()
                }
            }
            
            let geocoder = CLGeocoder()
            
            // Fetch cached values
            var cache = UserDefaults.standard.dictionary(forKey: "geocoded_locations_cache") as? [String: [String: String]] ?? [:]
            var updated = false
            
            // Capture a safe copy of photos to geocode on the MainActor
            let targets = await Task { @MainActor in
                manager.allPhotos.filter { $0.latitude != nil && $0.cityName == nil }
            }.value
            
            guard !targets.isEmpty else { return }
            
            var batchCount = 0
            
            for photo in targets {
                if Task.isCancelled { break }
                guard let lat = photo.latitude, let lon = photo.longitude else { continue }
                
                // Group coordinates to 2 decimal places to bypass duplicate queries (~1km precision)
                let key = String(format: "%.2f,%.2f", lat, lon)
                var city = "Unknown City"
                var country = "Unknown Country"
                var found = false
                
                if let cached = cache[key], let cachedCity = cached["city"], let cachedCountry = cached["country"] {
                    city = cachedCity
                    country = cachedCountry
                    found = true
                } else {
                    // Slow geocode query to stay within system rate limits
                    do {
                        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                        let location = CLLocation(latitude: lat, longitude: lon)
                        let placemarks = try await geocoder.reverseGeocodeLocation(location)
                        
                        if let placemark = placemarks.first {
                            city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? "Unknown City"
                            country = placemark.country ?? "Unknown Country"
                            
                            cache[key] = ["city": city, "country": country]
                            updated = true
                            found = true
                        }
                    } catch {
                        // Sleep a bit longer if we hit a rate limit, then continue
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        continue
                    }
                }
                
                if found {
                    let targetId = photo.id
                    let resolvedCity = city
                    let resolvedCountry = country
                    
                    await Task { @MainActor in
                        // Safe ID-based updates rather than index-based, prevents array index out of bounds crashes
                        if let idx = manager.allPhotos.firstIndex(where: { $0.id == targetId }) {
                            manager.allPhotos[idx].cityName = resolvedCity
                            manager.allPhotos[idx].countryName = resolvedCountry
                        }
                        if let idx = manager.photos.firstIndex(where: { $0.id == targetId }) {
                            manager.photos[idx].cityName = resolvedCity
                            manager.photos[idx].countryName = resolvedCountry
                        }
                    }.value
                    
                    batchCount += 1
                    // Periodic cache writes every 10 resolved items
                    if batchCount % 10 == 0 && updated {
                        let currentCache = cache
                        Task.detached(priority: .background) {
                            UserDefaults.standard.set(currentCache, forKey: "geocoded_locations_cache")
                        }
                        await Task { @MainActor in
                            manager.savePhotosToCache()
                        }.value
                    }
                }
            }
            
            if updated {
                UserDefaults.standard.set(cache, forKey: "geocoded_locations_cache")
            }
        }
    }
    
    // MARK: - High-Fidelity Procedural Mock Data Generator (Demo Mode)
    
    func loadDemoLibrary() {
        var mock: [Photo] = []
        let now = Date().timeIntervalSince1970
        let oneDay: Double = 86400
        let oneYear: Double = 86400 * 365
        
        // Define Travel Locations
        struct LocationSpec {
            let city: String
            let country: String
            let lat: Double
            let lon: Double
            let camera: String
            let isWidePreferring: Bool
        }
        
        let destinations = [
            LocationSpec(city: "Kyoto", country: "Japan", lat: 35.0116, lon: 135.7681, camera: "Fujifilm X-T5", isWidePreferring: false),
            LocationSpec(city: "Tokyo", country: "Japan", lat: 35.6762, lon: 139.6503, camera: "Fujifilm X-T5", isWidePreferring: false),
            LocationSpec(city: "Paris", country: "France", lat: 48.8566, lon: 2.3522, camera: "Sony A7R V", isWidePreferring: false),
            LocationSpec(city: "Rome", country: "Italy", lat: 41.9028, lon: 12.4964, camera: "Sony A7R V", isWidePreferring: false),
            LocationSpec(city: "Maui", country: "United States", lat: 20.7984, lon: -156.3319, camera: "DJI Mavic 3", isWidePreferring: true),
            LocationSpec(city: "Iceland Wilderness", country: "Iceland", lat: 64.1466, lon: -21.9426, camera: "Canon EOS R5", isWidePreferring: true),
            LocationSpec(city: "Cairo", country: "Egypt", lat: 30.0444, lon: 31.2357, camera: "Sony A7R V", isWidePreferring: false),
            LocationSpec(city: "Sydney", country: "Australia", lat: -33.8688, lon: 151.2093, camera: "iPhone 15 Pro", isWidePreferring: false)
        ]
        
        // Seed 1,320 photos captured over the past 5 years
        for i in 0..<1320 {
            // Distribute photos across destinations + some random home memories
            let destIdx = i % (destinations.count + 2)
            
            let isHome = destIdx >= destinations.count
            
            let city: String
            let country: String
            let lat: Double?
            let lon: Double?
            let camera: String
            let altitude: Double
            
            if isHome {
                city = "San Francisco"
                country = "United States"
                lat = 37.7749 + Double.random(in: -0.05...0.05)
                lon = -122.4194 + Double.random(in: -0.05...0.05)
                camera = "iPhone 15 Pro"
                altitude = Double.random(in: 10...60)
            } else {
                let d = destinations[destIdx]
                city = d.city
                country = d.country
                lat = d.lat + Double.random(in: -0.01...0.01)
                lon = d.lon + Double.random(in: -0.01...0.01)
                camera = d.camera
                
                if d.camera == "DJI Mavic 3" {
                    altitude = Double.random(in: 40...140) // Drone shots elevation!
                } else if d.city == "Iceland Wilderness" {
                    altitude = Double.random(in: 120...650) // Mountain elevations
                } else {
                    altitude = Double.random(in: 15...90)
                }
            }
            
            // Capture time: distributed over past 5 years (with peaks around summers/winters)
            let yearOffset = Double(i) / 264.0 // 1320 / 5 = 264 per year
            let baseDate = now - (yearOffset * oneYear)
            // Add a seasonal peak component (trips usually in July or December)
            let calendar = Calendar.current
            let randDays = Double.random(in: -20...20)
            let dateAdded = baseDate + (randDays * oneDay)
            
            // Capture hour distribution
            // Peak at sunset (17:00 - 19:00), midday (12:00 - 14:00), golden hour (06:00 - 08:00)
            let hourRandom = Double.random(in: 0...100)
            let captureHour: Int
            if hourRandom < 25 {
                captureHour = [17, 18, 19].randomElement()! // Sunset
            } else if hourRandom < 50 {
                captureHour = [11, 12, 13, 14, 15].randomElement()! // Midday focus
            } else if hourRandom < 70 {
                captureHour = [6, 7, 8].randomElement()! // Golden hour morning
            } else if hourRandom < 85 {
                captureHour = [20, 21, 22, 23].randomElement()! // Sunset Chill
            } else {
                captureHour = [0, 1, 2, 3, 4, 5].randomElement()! // Midnight owls
            }
            
            // Adjust mock date to have exact hour
            var components = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: dateAdded))
            components.hour = captureHour
            components.minute = Int.random(in: 0...59)
            let finalTimestamp = calendar.date(from: components)?.timeIntervalSince1970 ?? dateAdded
            
            // Favorites: 10% favorite rate
            let isFav = (i % 10 == 0)
            
            // Dimensions & aspect ratio
            let width: Int
            let height: Int
            let aspectRand = Double.random(in: 0...100)
            
            if camera == "DJI Mavic 3" || (isHome && aspectRand < 10) {
                // Wide / Panoramic crops
                width = 3980
                height = 1320
            } else if aspectRand < 40 {
                // Portrait 4:5 or 9:16
                width = 2448
                height = 3264
            } else if aspectRand < 85 {
                // Standard Landscape 3:2 or 4:3
                width = 3264
                height = 2448
            } else {
                // Square 1:1
                width = 2000
                height = 2000
            }
            
            // Filename extensions
            let isVideo = (i % 12 == 0) // 8% videos
            let ext = isVideo ? ["mp4", "mov"].randomElement()! : "jpg"
            let fn = isVideo ? "VID_\(1000 + i).\(ext)" : "IMG_\(4000 + i).\(ext)"
            
            mock.append(Photo(
                id: "demo-photo-\(i)",
                filename: fn,
                dateAdded: finalTimestamp,
                latitude: lat,
                longitude: lon,
                altitude: altitude,
                width: width,
                height: height,
                isFavorite: isFav,
                cityName: city,
                countryName: country
            ))
        }
        
        self.allPhotos = mock
        self.applyFilter()
    }
    
    // MARK: - Computed Properties for Photography Analytics
    
    var totalAssetsCount: Int {
        return photos.count
    }
    
    var favoritesCount: Int {
        return photos.filter(\.isFavorite).count
    }
    
    var favoritePercentage: Double {
        let total = Double(totalAssetsCount)
        guard total > 0 else { return 0.0 }
        return (Double(favoritesCount) / total) * 100.0
    }
    
    var videosCount: Int {
        return photos.filter { $0.mediaType == "Video" }.count
    }
    
    var photosCount: Int {
        return totalAssetsCount - videosCount
    }
    
    var dateRangeFormatted: String {
        guard !photos.isEmpty else { return "No Data" }
        let dates = photos.map(\.dateAdded)
        let minDate = Date(timeIntervalSince1970: dates.min() ?? 0)
        let maxDate = Date(timeIntervalSince1970: dates.max() ?? 0)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: minDate)) – \(formatter.string(from: maxDate))"
    }
    
    // Media format composition count
    var mediaTypeComposition: [GenreStat] {
        let total = Double(totalAssetsCount)
        guard total > 0 else { return [] }
        
        var photoCount = 0
        var videoCount = 0
        var livePhotoCount = 0
        
        for item in photos {
            if item.mediaType == "Video" {
                videoCount += 1
            } else if item.isFavorite && item.id.hashValue % 3 == 0 {
                // Heuristic: Classify a subset as live photos in demo/direct sync
                livePhotoCount += 1
            } else {
                photoCount += 1
            }
        }
        
        return [
            GenreStat(genre: "Still Photos", count: photoCount, percentage: (Double(photoCount) / total) * 100.0),
            GenreStat(genre: "Videos", count: videoCount, percentage: (Double(videoCount) / total) * 100.0),
            GenreStat(genre: "Live Photos", count: livePhotoCount, percentage: (Double(livePhotoCount) / total) * 100.0)
        ]
    }
    
    // Timeline of Photo Captures (growth month-by-month)
    var photosTimeline: [TimelineStat] {
        let cal = Calendar.current
        var groupings: [String: (date: Date, count: Int)] = [:]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        for item in photos {
            let date = item.capturedDate
            let components = cal.dateComponents([.year, .month], from: date)
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
    
    // Hourly capture counts
    var captureHourCounts: [Int: Int] {
        var counts: [Int: Int] = [:]
        let cal = Calendar.current
        for item in photos {
            let hour = cal.component(.hour, from: item.capturedDate)
            counts[hour, default: 0] += 1
        }
        return counts
    }
    
    // Categorize temporal photo capture slots
    var temporalCaptureStats: [TemporalStat] {
        let counts = captureHourCounts
        var morning = 0   // 6 AM - 12 PM
        var afternoon = 0 // 12 PM - 5 PM
        var golden = 0    // 5 PM - 8 PM (Sunset/Golden hours)
        var midnight = 0  // 8 PM - 6 AM (Night capture)
        
        for (hour, count) in counts {
            if hour >= 6 && hour < 12 {
                morning += count
            } else if hour >= 12 && hour < 17 {
                afternoon += count
            } else if hour >= 17 && hour < 20 {
                golden += count
            } else {
                midnight += count
            }
        }
        
        return [
            TemporalStat(
                period: "Morning Light",
                count: morning,
                description: "6 AM – 12 PM • Bright morning exposures & sunrise hues.",
                icon: "sunrise.fill",
                gradientColors: [.orange, .yellow]
            ),
            TemporalStat(
                period: "Midday Standard",
                count: afternoon,
                description: "12 PM – 5 PM • Bright daylight shots & sharp structural outlines.",
                icon: "sun.max.fill",
                gradientColors: [.emerald, .teal]
            ),
            TemporalStat(
                period: "Golden Glow",
                count: golden,
                description: "5 PM – 8 PM • Magic hours, warm lighting, & striking long shadows.",
                icon: "sunset.fill",
                gradientColors: [.purple, .pink]
            ),
            TemporalStat(
                period: "Night Nocturnes",
                count: midnight,
                description: "8 PM – 6 AM • Neon highlights, flash shots, & starry long exposures.",
                icon: "moon.stars.fill",
                gradientColors: [.indigo, .purple]
            )
        ]
    }
    
    // Camera gear stats
    var cameraDistribution: [CameraStat] {
        var counts: [String: Int] = [:]
        for item in photos {
            let camera: String
            // Guess camera based on filename or procedural index
            let num = item.id.hashValue
            if item.filename.contains("VID") {
                camera = "iPhone 15 Pro"
            } else if item.altitude ?? 0.0 > 100 && num % 4 == 0 {
                camera = "DJI Mavic 3"
            } else {
                let brands = ["Sony A7R V", "Fujifilm X-T5", "iPhone 15 Pro", "Canon EOS R5"]
                let idx = abs(num) % brands.count
                camera = brands[idx]
            }
            counts[camera, default: 0] += 1
        }
        return counts.map { CameraStat(camera: $0.key, count: $0.value) }.sorted(by: { $0.count > $1.count })
    }
    
    // Crop/Aspect ratio analysis
    var aspectRatios: [AspectRatioStat] {
        var counts: [String: Int] = [:]
        for item in photos {
            counts[item.aspectCategory, default: 0] += 1
        }
        let total = Double(totalAssetsCount)
        guard total > 0 else { return [] }
        
        return counts.map { cat, count in
            AspectRatioStat(category: cat, count: count, percentage: (Double(count) / total) * 100.0)
        }.sorted(by: { $0.count > $1.count })
    }
    
    // Geolocation Places: Cities and Countries visited
    var destinations: [DestinationStat] {
        var counts: [String: (city: String, country: String, count: Int)] = [:]
        for item in photos {
            guard let city = item.cityName, let country = item.countryName else { continue }
            let key = "\(city), \(country)"
            if let existing = counts[key] {
                counts[key] = (city, country, existing.count + 1)
            } else {
                counts[key] = (city, country, 1)
            }
        }
        return counts.values.map { DestinationStat(city: $0.city, country: $0.country, count: $0.count) }.sorted(by: { $0.count > $1.count })
    }
    
    var totalCitiesVisited: Int {
        return Set(photos.compactMap(\.cityName)).count
    }
    
    var totalCountriesVisited: Int {
        return Set(photos.compactMap(\.countryName)).count
    }
    
    let altitudeProfileLabels = ["< 20 m", "20 m - 100 m", "100 m - 500 m", "> 500 m"]
    
    var maxAltitudePhoto: Photo? {
        let validPhotos = photos.filter { photo in
            guard let alt = photo.altitude else { return false }
            return abs(alt) > 0.01 && alt >= -100.0 && alt <= 8500.0
        }
        return validPhotos.max(by: { ($0.altitude ?? 0.0) < ($1.altitude ?? 0.0) })
    }
    
    private var altitudeNumberFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f
    }
    
    var maxAltitudeFormatted: String {
        guard let alt = maxAltitudePhoto?.altitude else { return "0 meters" }
        let formattedVal = altitudeNumberFormatter.string(from: NSNumber(value: alt)) ?? String(format: "%.0f", alt)
        return "\(formattedVal) meters"
    }
    
    var maxAltitudeDetails: String {
        guard let photo = maxAltitudePhoto else { return "No altitude data" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: photo.capturedDate)
        
        if let city = photo.cityName, let country = photo.countryName {
            return "\(dateStr) • \(city), \(country)"
        } else if let lat = photo.latitude, let lon = photo.longitude {
            return String(format: "%@ • %.2f°, %.2f°", dateStr, lat, lon)
        } else {
            return dateStr
        }
    }
    
    var maxAltitude: Double {
        return maxAltitudePhoto?.altitude ?? 0.0
    }
    
    var northernMostPhoto: Photo? {
        return photos.filter { $0.latitude != nil }.max(by: { ($0.latitude ?? 0.0) < ($1.latitude ?? 0.0) })
    }
    
    var southernMostPhoto: Photo? {
        return photos.filter { $0.latitude != nil }.min(by: { ($0.latitude ?? 0.0) < ($1.latitude ?? 0.0) })
    }
    
    var northernMostFormatted: String {
        guard let lat = northernMostPhoto?.latitude else { return "Unknown Latitude" }
        return formatLatitude(lat)
    }
    
    var northernMostDetails: String {
        guard let photo = northernMostPhoto else { return "No coordinate data" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: photo.capturedDate)
        
        if let city = photo.cityName, let country = photo.countryName {
            return "\(dateStr) • \(city), \(country)"
        } else if let lat = photo.latitude, let lon = photo.longitude {
            return String(format: "%@ • %.2f°, %.2f°", dateStr, lat, lon)
        } else {
            return dateStr
        }
    }
    
    var southernMostFormatted: String {
        guard let lat = southernMostPhoto?.latitude else { return "Unknown Latitude" }
        return formatLatitude(lat)
    }
    
    var southernMostDetails: String {
        guard let photo = southernMostPhoto else { return "No coordinate data" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: photo.capturedDate)
        
        if let city = photo.cityName, let country = photo.countryName {
            return "\(dateStr) • \(city), \(country)"
        } else if let lat = photo.latitude, let lon = photo.longitude {
            return String(format: "%@ • %.2f°, %.2f°", dateStr, lat, lon)
        } else {
            return dateStr
        }
    }
    
    private func formatLatitude(_ lat: Double) -> String {
        if lat >= 0 {
            return String(format: "%.2f° N", lat)
        } else {
            return String(format: "%.2f° S", abs(lat))
        }
    }
    
    // Altitude metrics distribution
    var altitudeProfile: [AltitudeBucket] {
        var seaLevel = 0      // 0 - 20 meters
        var normalElevation = 0 // 20 - 100 meters
        var mountains = 0     // 100 - 500 meters
        var airplane = 0      // 500+ meters
        
        for item in photos {
            guard let alt = item.altitude else { continue }
            // Ignore placeholders, negative GPS noise, and cruising airplane flights
            if abs(alt) < 0.01 || alt < -100.0 || alt > 8500.0 {
                continue
            }
            
            if alt < 20.0 {
                seaLevel += 1
            } else if alt < 100.0 {
                normalElevation += 1
            } else if alt < 500.0 {
                mountains += 1
            } else {
                airplane += 1
            }
        }
        
        return [
            AltitudeBucket(label: altitudeProfileLabels[0], count: seaLevel),
            AltitudeBucket(label: altitudeProfileLabels[1], count: normalElevation),
            AltitudeBucket(label: altitudeProfileLabels[2], count: mountains),
            AltitudeBucket(label: altitudeProfileLabels[3], count: airplane)
        ]
    }
    
    // Photography Aura Persona Profile
    var photographyPersona: PersonaProfile {
        let total = Double(totalAssetsCount)
        guard total > 0 else {
            return PersonaProfile(
                name: "The Visual Explorer",
                subtitle: "First Impressions",
                description: "Your creative photography style will take form once you sync your Photos library and catalog your captures.",
                nostalgiaIndex: 0, varietyScore: 0, focusScore: 0, loyaltyScore: 0,
                gradientColors: [.emerald, .teal]
            )
        }
        
        // 1. Travel Index (Ratio of non-home captures)
        let totalDestinations = Double(destinations.count)
        let travelScore = min(100.0, totalDestinations * 12.0)
        
        // 2. Camera Gear Index (Mirrorless vs Smartphone)
        let mirrorlessCount = Double(photos.filter { item in
            let num = item.id.hashValue
            let isVideo = item.filename.contains("VID")
            if isVideo { return false }
            let brandIdx = abs(num) % 4
            return brandIdx != 2 // Index 2 is iPhone 15 Pro
        }.count)
        let gearScore = (mirrorlessCount / total) * 100.0
        
        // 3. Golden Hour Ratio
        let goldenHourCount = Double(photos.filter { item in
            let hour = Calendar.current.component(.hour, from: item.capturedDate)
            return hour >= 17 && hour < 20 // 5 PM - 8 PM (Sunset/Magic hour)
        }.count)
        let goldenHourScore = (goldenHourCount / total) * 100.0
        
        // 4. Composition Focus (Panoramic/Wide ratio)
        let wideCount = Double(photos.filter { item in
            item.aspectCategory == "Panoramic"
        }.count)
        let compositionScore = (wideCount / total) * 100.0
        
        // 5. Night Owl Ratio (8 PM - 6 AM)
        let nightCount = Double(photos.filter { item in
            let hour = Calendar.current.component(.hour, from: item.capturedDate)
            return hour >= 20 || hour < 6
        }.count)
        let nightScore = (nightCount / total) * 100.0
        
        // Persona selection logic
        let name: String
        let subtitle: String
        let description: String
        let gradientColors: [Color]
        
        if travelScore >= 60.0 {
            name = "The Jetsetter Archivist"
            subtitle = "Global Visual Voyager"
            description = "Your camera is a passport. You have traveled across multiple cities and countries, building a gorgeous visual archive of diverse worldwide cultures and landmarks."
            gradientColors = [.emerald, .teal]
        } else if goldenHourScore >= 20.0 {
            name = "The Golden Hour Guru"
            subtitle = "Magic Hour Connoisseur"
            description = "You chase the warm glow. A high percentage of your photographs are captured during the brief, gorgeous intervals of sunrise and sunset, celebrating glowing shadows and ambient warmth."
            gradientColors = [.orange, .pink]
        } else if gearScore >= 70.0 {
            name = "The Dedicated Purist"
            subtitle = "Fine Art Photographer"
            description = "You reject mobile convenience in favor of pure optical craft. Your catalog is dominated by fine-lens captures from dedicated mirrorless systems, focusing on rich image quality."
            gradientColors = [.cyan, .blue]
        } else if compositionScore >= 12.0 {
            name = "The Cinematic Landscape"
            subtitle = "Panoramic Horizonist"
            description = "You think in wide screens. Your collection features an outstanding ratio of ultra-wide, cinematic, and high-altitude landscape perspectives, capturing natural grandeur."
            gradientColors = [.purple, .indigo]
        } else if nightScore >= 35.0 {
            name = "The Night Owl Artist"
            subtitle = "Low-Light Visionary"
            description = "The darkness is your canvas. You specialize in low-light environments, neon highlights, flash portraits, and long exposures captured under the cover of night."
            gradientColors = [.indigo, .purple]
        } else {
            name = "The Harmonious Historian"
            subtitle = "Balanced Memory Archivist"
            description = "You capture the full spectrum of life. Your photography library displays a well-balanced profile, harmonizing daytime memories, travel snapshots, mobile phone grabs, and classic favorites."
            gradientColors = [.teal, .indigo]
        }
        
        return PersonaProfile(
            name: name, subtitle: subtitle,
            description: description,
            nostalgiaIndex: travelScore, varietyScore: gearScore,
            focusScore: goldenHourScore, loyaltyScore: compositionScore,
            gradientColors: gradientColors
        )
    }
}
