import Foundation
import SwiftUI
import Combine
import AppKit
import CoreLocation
import MapKit
import Photos

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
    
    @Published var photos: [Photo] = [] {
        didSet {
            recalculatePhotosAnalytics()
        }
    }
    @Published var allPhotos: [Photo] = []
    @Published var isLoading: Bool = false
    @Published var syncError: String? = nil
    @Published var syncStatus: String = ""
    @Published var syncProgressFraction: Double = 0.0
    @Published var isGeocoding: Bool = false
    @Published var isGeocodingPaused: Bool = false
    @Published var sourceMode: SourceMode = .demo
    @Published var photosAppRunningState: PhotosAppState = .unknown
    
    @Published var currentFilter: TimeFilter = .specificYear(Calendar.current.component(.year, from: Date()))
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var customEndDate: Date = Date()
    
    @Published var precomputedAnalytics: PhotosAnalytics? = nil
    private var recalculateTask: Task<Void, Never>? = nil
    
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
            var cacheUpdatedNeeded = false
            
            // Clean altitudes and resolve missing cameraModel in cached items
            for idx in 0..<cached.count {
                // 1. Clean altitudes
                if let alt = cached[idx].altitude {
                    if abs(alt) < 0.01 || alt < -100.0 || alt > 8500.0 {
                        cached[idx].altitude = nil
                        cacheUpdatedNeeded = true
                    }
                }
                
                // 2. Resolve missing or nil cameraModel
                if cached[idx].cameraModel == nil {
                    cached[idx].cameraModel = cleanCameraModel(
                        kvcModel: nil,
                        filename: cached[idx].filename,
                        isLivePhoto: cached[idx].isLivePhoto,
                        width: cached[idx].width,
                        height: cached[idx].height
                    )
                    cacheUpdatedNeeded = true
                }
            }
            
            if !cached.isEmpty {
                self.allPhotos = cached
                self.applyFilter()
                
                // Save clean cache back to disk if we made corrections
                if cacheUpdatedNeeded {
                    savePhotosToCache()
                }
            }
        } catch {
            // Silently fall back if the cache is corrupt or missing
        }
    }
    
    nonisolated private func cleanCameraModel(kvcModel: String?, filename: String, isLivePhoto: Bool, width: Int, height: Int) -> String {
        let lowerFn = filename.lowercased()
        
        // Resolve camera model from EXIF metadata if present
        if let kvc = kvcModel?.trimmingCharacters(in: .whitespacesAndNewlines), !kvc.isEmpty {
            let lowerKvc = kvc.lowercased()
            if lowerKvc.contains("gopro") || lowerKvc.contains("hero") {
                if lowerKvc.contains("gopro") {
                    return kvc // e.g. "GoPro HERO10 Black"
                } else {
                    return "GoPro \(kvc)" // e.g. "GoPro HERO9 Black"
                }
            }
            if lowerKvc.contains("iphone") {
                if kvc.hasPrefix("Apple ") {
                    return String(kvc.dropFirst(6)) // "Apple iPhone 15 Pro" -> "iPhone 15 Pro"
                }
                return kvc
            }
            if lowerKvc.contains("apple") {
                return kvc // E.g. "Apple Watch"
            }
            return kvc
        }
        
        // Fallback to filename heuristics (GoPro: GOPR, GP, G0, GX, GH, gopro; otherwise iPhone)
        if lowerFn.hasPrefix("gopr") || lowerFn.hasPrefix("gp") || lowerFn.hasPrefix("g0") || lowerFn.hasPrefix("gx") || lowerFn.hasPrefix("gh") || lowerFn.contains("gopro") {
            return "GoPro HERO"
        }
        
        return "iPhone"
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
        let currentYear = cal.component(.year, from: Date())
        let years = allPhotos.map { item -> Int in
            cal.component(.year, from: item.capturedDate)
        }
        var uniqueYears = Set(years)
        uniqueYears.insert(currentYear)
        return Array(uniqueYears).sorted(by: >)
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
    
    // Reveal a specific photo in the Photos app
    func revealPhotoInPhotosApp(photoId: String) {
        guard sourceMode == .direct else { return }
        
        let scriptText = """
        tell application "Photos"
            activate
            try
                set targetPhoto to media item id "\(photoId)"
                spotlight targetPhoto
            end try
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", scriptText]
        try? process.run()
    }

    
    // MARK: - Direct Apple Photos Connection (JXA Engine)
    
    func fetchDirectLibrary(forceLaunch: Bool = false) async {
        self.isLoading = true
        self.syncError = nil
        self.syncStatus = "Requesting access to Photo Library..."
        self.syncProgressFraction = 0.0
        
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
        
        // Build a thread-safe lookup map of the cached photos
        let cacheMap = Dictionary(uniqueKeysWithValues: self.allPhotos.map { ($0.id, $0) })
        
        let manager = self
        let fetchedPhotos = await Task.detached(priority: .userInitiated) { [manager, cacheMap] () -> [Photo] in
            var list: [Photo] = []
            let total = fetchResult.count
            list.reserveCapacity(total)
            
            fetchResult.enumerateObjects { (asset, index, stop) in
                let id = asset.localIdentifier
                
                // Fast path: check disk cache map
                if let cached = cacheMap[id] {
                    var updatedCached = cached
                    let assetLat = asset.location?.coordinate.latitude
                    let assetLon = asset.location?.coordinate.longitude
                    
                    if cached.isFavorite != asset.isFavorite || cached.latitude != assetLat || cached.longitude != assetLon {
                        let locationChanged = cached.latitude != assetLat || cached.longitude != assetLon
                        
                        var alt: Double? = cached.altitude
                        if locationChanged {
                            alt = nil
                            if let loc = asset.location {
                                if loc.verticalAccuracy >= 0 {
                                    let rawAlt = loc.altitude
                                    if abs(rawAlt) > 0.01 && rawAlt >= -100.0 && rawAlt <= 8500.0 {
                                        alt = rawAlt
                                    }
                                }
                            }
                        }
                        
                        updatedCached = Photo(
                            id: cached.id,
                            filename: cached.filename,
                            dateAdded: cached.dateAdded,
                            latitude: assetLat,
                            longitude: assetLon,
                            altitude: alt,
                            width: cached.width,
                            height: cached.height,
                            isFavorite: asset.isFavorite,
                            cityName: locationChanged ? nil : cached.cityName,
                            countryName: locationChanged ? nil : cached.countryName,
                            isLivePhoto: cached.isLivePhoto,
                            cameraModel: cached.cameraModel
                        )
                    }
                    
                    list.append(updatedCached)
                    
                    // Real-time progress updates to MainActor every 100 files
                    if index % 100 == 0 || index == total - 1 {
                        let fraction = Double(index + 1) / Double(max(1, total))
                        Task { @MainActor in
                            manager.syncProgressFraction = fraction
                            manager.syncStatus = "Analyzing captures (\(index + 1) of \(total))..."
                        }
                    }
                    return
                }
                
                // Super safe exception-guarded filename lookup using responds(to:) with robust public PHAssetResource fallback
                var filename = "IMG_\(index).jpg"
                if asset.responds(to: NSSelectorFromString("filename")),
                   let name = asset.value(forKey: "filename") as? String,
                   !name.isEmpty {
                    filename = name
                } else {
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let originalName = resources.first?.originalFilename, !originalName.isEmpty {
                        filename = originalName
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
                
                let isLive = asset.mediaSubtypes.contains(.photoLive)
                
                var kvcCamera: String? = nil
                if asset.responds(to: NSSelectorFromString("photosInfoPanelExtendedProperties")),
                   let extendedProps = asset.value(forKey: "photosInfoPanelExtendedProperties") as? NSObject {
                    kvcCamera = extendedProps.value(forKey: "cameraModel") as? String
                }
                let camera = manager.cleanCameraModel(kvcModel: kvcCamera, filename: filename, isLivePhoto: isLive, width: width, height: height)
                
                let photo = Photo(
                    id: id,
                    filename: filename,
                    dateAdded: dateAdded,
                    latitude: latitude,
                    longitude: longitude,
                    altitude: altitude,
                    width: width,
                    height: height,
                    isFavorite: isFavorite,
                    isLivePhoto: isLive,
                    cameraModel: camera
                )
                list.append(photo)
                
                // Real-time progress updates to MainActor every 100 files
                if index % 100 == 0 || index == total - 1 {
                    let fraction = Double(index + 1) / Double(max(1, total))
                    Task { @MainActor in
                        manager.syncProgressFraction = fraction
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
        self.syncProgressFraction = 1.0
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
                
                // Read all data first to prevent process block/deadlock when buffer exceeds 64KB
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                process.waitUntilExit()
                
                let status = process.terminationStatus
                if status == 0 {
                    if let output = String(data: data, encoding: .utf8) {
                        return .success(output)
                    } else {
                        return .failure(NSError(domain: "OsaScriptError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read string output."]))
                    }
                } else {
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
    
    func startGeocoding() {
        guard !isGeocodingPaused else {
            isGeocoding = false
            return
        }
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
                        if let request = MKReverseGeocodingRequest(location: location) {
                            let mapItems = try await request.mapItems
                            if let representations = mapItems.first?.addressRepresentations {
                                city = representations.cityName ?? "Unknown City"
                                country = representations.regionName ?? "Unknown Country"
                                
                                cache[key] = ["city": city, "country": country]
                                updated = true
                                found = true
                            }
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
    
    func toggleGeocodingPause() {
        if isGeocodingPaused {
            isGeocodingPaused = false
            startGeocoding()
        } else {
            isGeocodingPaused = true
            geocodeTask?.cancel()
            geocodeTask = nil
            isGeocoding = false
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
            LocationSpec(city: "Kyoto", country: "Japan", lat: 35.0116, lon: 135.7681, camera: "iPhone", isWidePreferring: false),
            LocationSpec(city: "Tokyo", country: "Japan", lat: 35.6762, lon: 139.6503, camera: "iPhone", isWidePreferring: false),
            LocationSpec(city: "Paris", country: "France", lat: 48.8566, lon: 2.3522, camera: "iPhone", isWidePreferring: false),
            LocationSpec(city: "Rome", country: "Italy", lat: 41.9028, lon: 12.4964, camera: "iPhone", isWidePreferring: false),
            LocationSpec(city: "Maui", country: "United States", lat: 20.7984, lon: -156.3319, camera: "GoPro HERO", isWidePreferring: true),
            LocationSpec(city: "Iceland Wilderness", country: "Iceland", lat: 64.1466, lon: -21.9426, camera: "GoPro HERO", isWidePreferring: true),
            LocationSpec(city: "Cairo", country: "Egypt", lat: 30.0444, lon: 31.2357, camera: "iPhone", isWidePreferring: false),
            LocationSpec(city: "Sydney", country: "Australia", lat: -33.8688, lon: 151.2093, camera: "iPhone", isWidePreferring: false)
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
                camera = ["iPhone 15 Pro", "iPhone 14 Pro", "iPhone 13 Mini", "iPhone 12"].randomElement()!
                altitude = Double.random(in: 10...60)
            } else {
                let d = destinations[destIdx]
                city = d.city
                country = d.country
                lat = d.lat + Double.random(in: -0.01...0.01)
                lon = d.lon + Double.random(in: -0.01...0.01)
                
                if d.camera == "iPhone" {
                    camera = ["iPhone 15 Pro", "iPhone 14 Pro", "iPhone 13 Mini", "iPhone 12"].randomElement()!
                } else if d.camera == "GoPro HERO" {
                    camera = ["GoPro HERO10 Black", "GoPro HERO11 Black", "GoPro HERO9 Black"].randomElement()!
                } else {
                    camera = d.camera
                }
                
                if d.camera == "GoPro HERO" {
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
            
            if camera == "GoPro HERO" || (isHome && aspectRand < 10) {
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
            let fn: String
            if camera == "GoPro HERO" {
                fn = isVideo ? "GP_\(1000 + i).\(ext)" : "GOPR\(4000 + i).\(ext)"
            } else {
                fn = isVideo ? "VID_\(1000 + i).\(ext)" : "IMG_\(4000 + i).\(ext)"
            }
            
            let isLive = !isVideo && (i % 3 != 0) // ~67% Live Photos
            
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
                countryName: country,
                isLivePhoto: isLive,
                cameraModel: camera
            ))
        }
        
        self.allPhotos = mock
        self.applyFilter()
    }
    
    // MARK: - Computed Properties for Photography Analytics
    
    // MARK: - Precomputed Analytics Getters
    
    var totalAssetsCount: Int { precomputedAnalytics?.totalAssetsCount ?? photos.count }
    var favoritesCount: Int { precomputedAnalytics?.favoritesCount ?? 0 }
    var favoritePercentage: Double { precomputedAnalytics?.favoritePercentage ?? 0.0 }
    var videosCount: Int { precomputedAnalytics?.videosCount ?? 0 }
    var photosCount: Int { precomputedAnalytics?.photosCount ?? 0 }
    var dateRangeFormatted: String { precomputedAnalytics?.dateRangeFormatted ?? "No Data" }
    var mediaTypeComposition: [GenreStat] { precomputedAnalytics?.mediaTypeComposition ?? [] }
    var photosTimeline: [TimelineStat] { precomputedAnalytics?.photosTimeline ?? [] }
    var captureHourCounts: [Int: Int] { precomputedAnalytics?.captureHourCounts ?? [:] }
    var hourlyHistogramData: [HistogramDataPoint] { precomputedAnalytics?.hourlyHistogramData ?? [] }
    var weekdayHistogramData: [HistogramDataPoint] { precomputedAnalytics?.weekdayHistogramData ?? [] }
    var dayOfMonthHistogramData: [HistogramDataPoint] { precomputedAnalytics?.dayOfMonthHistogramData ?? [] }
    var monthHistogramData: [HistogramDataPoint] { precomputedAnalytics?.monthHistogramData ?? [] }
    var peakWeekday: String { precomputedAnalytics?.peakWeekday ?? "Unknown Day" }
    var peakWeekdayPercentage: Double { precomputedAnalytics?.peakWeekdayPercentage ?? 0.0 }
    var temporalCaptureStats: [TemporalStat] { precomputedAnalytics?.temporalCaptureStats ?? [] }
    var cameraDistribution: [CameraStat] { precomputedAnalytics?.cameraDistribution ?? [] }
    var aspectRatios: [AspectRatioStat] { precomputedAnalytics?.aspectRatios ?? [] }
    var destinations: [DestinationStat] { precomputedAnalytics?.destinations ?? [] }
    var totalCitiesVisited: Int { precomputedAnalytics?.totalCitiesVisited ?? 0 }
    var totalCountriesVisited: Int { precomputedAnalytics?.totalCountriesVisited ?? 0 }
    var maxAltitudePhoto: Photo? { precomputedAnalytics?.maxAltitudePhoto }
    var maxAltitudeFormatted: String { precomputedAnalytics?.maxAltitudeFormatted ?? "0 meters" }
    var maxAltitudeDetails: String { precomputedAnalytics?.maxAltitudeDetails ?? "No altitude data" }
    var maxAltitude: Double { precomputedAnalytics?.maxAltitude ?? 0.0 }
    var northernMostPhoto: Photo? { precomputedAnalytics?.northernMostPhoto }
    var southernMostPhoto: Photo? { precomputedAnalytics?.southernMostPhoto }
    var northernMostFormatted: String { precomputedAnalytics?.northernMostFormatted ?? "Unknown Latitude" }
    var northernMostDetails: String { precomputedAnalytics?.northernMostDetails ?? "No coordinate data" }
    var southernMostFormatted: String { precomputedAnalytics?.southernMostFormatted ?? "Unknown Latitude" }
    var southernMostDetails: String { precomputedAnalytics?.southernMostDetails ?? "No coordinate data" }
    var altitudeProfile: [AltitudeBucket] { precomputedAnalytics?.altitudeProfile ?? [] }
    let altitudeProfileLabels = ["< 20 m", "20 m - 100 m", "100 m - 500 m", "> 500 m"]
    var photographyPersona: PersonaProfile { 
        precomputedAnalytics?.photographyPersona ?? PersonaProfile(
            name: "The Visual Explorer",
            subtitle: "First Impressions",
            description: "Your creative photography style will take form once you sync your Photos library and catalog your captures.",
            nostalgiaIndex: 0, varietyScore: 0, focusScore: 0, loyaltyScore: 0,
            gradientColors: [.emerald, .teal]
        )
    }
    
    // Sidebar precomputed clusters
    var precomputedCityClusters: [MappedCluster] { precomputedAnalytics?.cityClusters ?? [] }
    var precomputedCountryClusters: [MappedCluster] { precomputedAnalytics?.countryClusters ?? [] }
    
    // Map precomputed clusters by zoom level
    var precomputedMapClusters: [MapZoomLevel: [MappedCluster]] { precomputedAnalytics?.mapClustersByZoomLevel ?? [:] }
    
    func recalculatePhotosAnalytics(synchronous: Bool = false) {
        let currentPhotos = self.photos
        if synchronous || currentPhotos.count < 2000 {
            recalculateTask?.cancel()
            let stats = Self.computeAnalytics(for: currentPhotos)
            self.precomputedAnalytics = stats
        } else {
            recalculateTask?.cancel()
            recalculateTask = Task.detached(priority: .userInitiated) {
                let stats = Self.computeAnalytics(for: currentPhotos)
                if Task.isCancelled { return }
                await MainActor.run {
                    self.precomputedAnalytics = stats
                }
            }
        }
    }
    
    nonisolated static func computeAnalytics(for photos: [Photo]) -> PhotosAnalytics {
        let totalAssetsCount = photos.count
        let favoritesCount = photos.filter(\.isFavorite).count
        let favoritePercentage: Double = totalAssetsCount > 0 ? (Double(favoritesCount) / Double(totalAssetsCount)) * 100.0 : 0.0
        let videosCount = photos.filter { $0.mediaType == "Video" }.count
        let photosCount = totalAssetsCount - videosCount
        
        let dateRangeFormatted: String
        if !photos.isEmpty {
            let dates = photos.map(\.dateAdded)
            let minDate = Date(timeIntervalSince1970: dates.min() ?? 0)
            let maxDate = Date(timeIntervalSince1970: dates.max() ?? 0)
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            dateRangeFormatted = "\(formatter.string(from: minDate)) – \(formatter.string(from: maxDate))"
        } else {
            dateRangeFormatted = "No Data"
        }
        
        let totalDouble = Double(totalAssetsCount)
        var pCount = 0
        var vCount = 0
        var lpCount = 0
        for item in photos {
            if item.mediaType == "Video" {
                vCount += 1
            } else if item.isLivePhoto {
                lpCount += 1
            } else {
                pCount += 1
            }
        }
        let mediaTypeComposition = totalDouble > 0 ? [
            GenreStat(genre: "Still Photos", count: pCount, percentage: (Double(pCount) / totalDouble) * 100.0),
            GenreStat(genre: "Videos", count: vCount, percentage: (Double(vCount) / totalDouble) * 100.0),
            GenreStat(genre: "Live Photos", count: lpCount, percentage: (Double(lpCount) / totalDouble) * 100.0)
        ] : []
        
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
        let photosTimeline = groupings.values.map { val in
            TimelineStat(date: val.date, monthYearString: formatter.string(from: val.date), count: val.count)
        }.sorted(by: { $0.date < $1.date })
        
        var captureHourCounts: [Int: Int] = [:]
        for item in photos {
            let hour = cal.component(.hour, from: item.capturedDate)
            captureHourCounts[hour, default: 0] += 1
        }
        
        var photoCounts = [Int: Int]()
        var videoCounts = [Int: Int]()
        for item in photos {
            let hour = cal.component(.hour, from: item.capturedDate)
            if item.mediaType == "Video" {
                videoCounts[hour, default: 0] += 1
            } else {
                photoCounts[hour, default: 0] += 1
            }
        }
        var hourlyHistogramData = [HistogramDataPoint]()
        for hour in 0..<24 {
            let suffix = hour >= 12 ? "PM" : "AM"
            let val = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
            let label = "\(val) \(suffix)"
            hourlyHistogramData.append(HistogramDataPoint(intKey: hour, label: label, count: photoCounts[hour, default: 0], type: "Photo"))
            hourlyHistogramData.append(HistogramDataPoint(intKey: hour, label: label, count: videoCounts[hour, default: 0], type: "Video"))
        }
        
        var photoCountsWD = [Int: Int]()
        var videoCountsWD = [Int: Int]()
        for item in photos {
            let weekday = cal.component(.weekday, from: item.capturedDate)
            if item.mediaType == "Video" {
                videoCountsWD[weekday, default: 0] += 1
            } else {
                photoCountsWD[weekday, default: 0] += 1
            }
        }
        let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let order = [2, 3, 4, 5, 6, 7, 1]
        var weekdayHistogramData = [HistogramDataPoint]()
        for (index, day) in order.enumerated() {
            let label = symbols[day - 1]
            weekdayHistogramData.append(HistogramDataPoint(intKey: index + 1, label: label, count: photoCountsWD[day, default: 0], type: "Photo"))
            weekdayHistogramData.append(HistogramDataPoint(intKey: index + 1, label: label, count: videoCountsWD[day, default: 0], type: "Video"))
        }
        
        var photoCountsDOM = [Int: Int]()
        var videoCountsDOM = [Int: Int]()
        for item in photos {
            let day = cal.component(.day, from: item.capturedDate)
            if item.mediaType == "Video" {
                videoCountsDOM[day, default: 0] += 1
            } else {
                photoCountsDOM[day, default: 0] += 1
            }
        }
        var dayOfMonthHistogramData = [HistogramDataPoint]()
        for day in 1...31 {
            let label = "\(day)"
            dayOfMonthHistogramData.append(HistogramDataPoint(intKey: day, label: label, count: photoCountsDOM[day, default: 0], type: "Photo"))
            dayOfMonthHistogramData.append(HistogramDataPoint(intKey: day, label: label, count: videoCountsDOM[day, default: 0], type: "Video"))
        }
        
        var photoCountsMon = [Int: Int]()
        var videoCountsMon = [Int: Int]()
        for item in photos {
            let month = cal.component(.month, from: item.capturedDate)
            if item.mediaType == "Video" {
                videoCountsMon[month, default: 0] += 1
            } else {
                photoCountsMon[month, default: 0] += 1
            }
        }
        let shortMonthSymbols = formatter.shortMonthSymbols ?? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var monthHistogramData = [HistogramDataPoint]()
        for month in 1...12 {
            let label = shortMonthSymbols[month - 1]
            monthHistogramData.append(HistogramDataPoint(intKey: month, label: label, count: photoCountsMon[month, default: 0], type: "Photo"))
            monthHistogramData.append(HistogramDataPoint(intKey: month, label: label, count: videoCountsMon[month, default: 0], type: "Video"))
        }
        
        var weekdayCounts: [Int: Int] = [:]
        for item in photos {
            let day = cal.component(.weekday, from: item.capturedDate)
            weekdayCounts[day, default: 0] += 1
        }
        let peakDay = weekdayCounts.max(by: { $0.value < $1.value })?.key ?? 1
        let weekdaySymbolsFull = formatter.weekdaySymbols ?? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let peakWeekday = weekdaySymbolsFull[peakDay - 1]
        
        let peakCount = weekdayCounts.values.max() ?? 0
        let peakWeekdayPercentage = totalAssetsCount > 0 ? (Double(peakCount) / Double(totalAssetsCount)) * 100.0 : 0.0
        
        var morningTemp = 0
        var afternoonTemp = 0
        var goldenTemp = 0
        var midnightTemp = 0
        for (hour, count) in captureHourCounts {
            if hour >= 6 && hour < 12 {
                morningTemp += count
            } else if hour >= 12 && hour < 17 {
                afternoonTemp += count
            } else if hour >= 17 && hour < 20 {
                goldenTemp += count
            } else {
                midnightTemp += count
            }
        }
        let temporalCaptureStats = [
            TemporalStat(
                period: "Morning Light",
                count: morningTemp,
                description: "6 AM – 12 PM • Bright morning exposures & sunrise hues.",
                icon: "sunrise.fill",
                gradientColors: [.orange, .yellow]
            ),
            TemporalStat(
                period: "Midday Standard",
                count: afternoonTemp,
                description: "12 PM – 5 PM • Bright daylight shots & sharp structural outlines.",
                icon: "sun.max.fill",
                gradientColors: [.emerald, .teal]
            ),
            TemporalStat(
                period: "Golden Glow",
                count: goldenTemp,
                description: "5 PM – 8 PM • Magic hours, warm lighting, & striking long shadows.",
                icon: "sunset.fill",
                gradientColors: [.purple, .pink]
            ),
            TemporalStat(
                period: "Night Nocturnes",
                count: midnightTemp,
                description: "8 PM – 6 AM • Neon highlights, flash shots, & starry long exposures.",
                icon: "moon.stars.fill",
                gradientColors: [.indigo, .purple]
            )
        ]
        
        var cameraCounts: [String: Int] = [:]
        for item in photos {
            let camera = item.cameraModel ?? "iPhone"
            cameraCounts[camera, default: 0] += 1
        }
        let cameraDistribution = cameraCounts.map { CameraStat(camera: $0.key, count: $0.value) }.sorted(by: { $0.count > $1.count })
        
        var aspectCounts: [String: Int] = [:]
        for item in photos {
            aspectCounts[item.aspectCategory, default: 0] += 1
        }
        let aspectRatios = totalAssetsCount > 0 ? aspectCounts.map { cat, count in
            AspectRatioStat(category: cat, count: count, percentage: (Double(count) / Double(totalAssetsCount)) * 100.0)
        }.sorted(by: { $0.count > $1.count }) : []
        
        var destCounts: [String: (city: String, country: String, count: Int)] = [:]
        for item in photos {
            guard let city = item.cityName, let country = item.countryName else { continue }
            let key = "\(city), \(country)"
            if let existing = destCounts[key] {
                destCounts[key] = (city, country, existing.count + 1)
            } else {
                destCounts[key] = (city, country, 1)
            }
        }
        let destinations = destCounts.values.map { DestinationStat(city: $0.city, country: $0.country, count: $0.count) }.sorted(by: { $0.count > $1.count })
        let totalCitiesVisited = Set(photos.compactMap(\.cityName)).count
        let totalCountriesVisited = Set(photos.compactMap(\.countryName)).count
        
        let validPhotos = photos.filter { photo in
            guard let alt = photo.altitude else { return false }
            return abs(alt) > 0.01 && alt >= -100.0 && alt <= 8500.0
        }
        let maxAltitudePhoto = validPhotos.max(by: { ($0.altitude ?? 0.0) < ($1.altitude ?? 0.0) })
        
        let altFormatter = NumberFormatter()
        altFormatter.numberStyle = .decimal
        altFormatter.groupingSeparator = ","
        altFormatter.maximumFractionDigits = 0
        let maxAltitudeFormatted: String
        if let alt = maxAltitudePhoto?.altitude {
            let formattedVal = altFormatter.string(from: NSNumber(value: alt)) ?? String(format: "%.0f", alt)
            maxAltitudeFormatted = "\(formattedVal) meters"
        } else {
            maxAltitudeFormatted = "0 meters"
        }
        
        let maxAltitudeDetails: String
        if let photo = maxAltitudePhoto {
            let formatterD = DateFormatter()
            formatterD.dateStyle = .medium
            formatterD.timeStyle = .none
            let dateStr = formatterD.string(from: photo.capturedDate)
            if let city = photo.cityName, let country = photo.countryName {
                maxAltitudeDetails = "\(dateStr) • \(city), \(country)"
            } else if let lat = photo.latitude, let lon = photo.longitude {
                maxAltitudeDetails = String(format: "%@ • %.2f°, %.2f°", dateStr, lat, lon)
            } else {
                maxAltitudeDetails = dateStr
            }
        } else {
            maxAltitudeDetails = "No altitude data"
        }
        let maxAltitude = maxAltitudePhoto?.altitude ?? 0.0
        
        let northernMostPhoto = photos.filter { $0.latitude != nil }.max(by: { ($0.latitude ?? 0.0) < ($1.latitude ?? 0.0) })
        let southernMostPhoto = photos.filter { $0.latitude != nil }.min(by: { ($0.latitude ?? 0.0) < ($1.latitude ?? 0.0) })
        
        let formatLat = { (lat: Double) -> String in
            if lat >= 0 {
                return String(format: "%.2f° N", lat)
            } else {
                return String(format: "%.2f° S", abs(lat))
            }
        }
        
        let northernMostFormatted = northernMostPhoto?.latitude.map(formatLat) ?? "Unknown Latitude"
        let northernMostDetails: String
        if let photo = northernMostPhoto {
            let formatterD = DateFormatter()
            formatterD.dateStyle = .medium
            formatterD.timeStyle = .none
            let dateStr = formatterD.string(from: photo.capturedDate)
            if let city = photo.cityName, let country = photo.countryName {
                northernMostDetails = "\(dateStr) • \(city), \(country)"
            } else if let lat = photo.latitude, let lon = photo.longitude {
                northernMostDetails = String(format: "%@ • %.2f°, %.2f°", dateStr, lat, lon)
            } else {
                northernMostDetails = dateStr
            }
        } else {
            northernMostDetails = "No coordinate data"
        }
        
        let southernMostFormatted = southernMostPhoto?.latitude.map(formatLat) ?? "Unknown Latitude"
        let southernMostDetails: String
        if let photo = southernMostPhoto {
            let formatterD = DateFormatter()
            formatterD.dateStyle = .medium
            formatterD.timeStyle = .none
            let dateStr = formatterD.string(from: photo.capturedDate)
            if let city = photo.cityName, let country = photo.countryName {
                southernMostDetails = "\(dateStr) • \(city), \(country)"
            } else if let lat = photo.latitude, let lon = photo.longitude {
                southernMostDetails = String(format: "%@ • %.2f°, %.2f°", dateStr, lat, lon)
            } else {
                southernMostDetails = dateStr
            }
        } else {
            southernMostDetails = "No coordinate data"
        }
        
        var seaLevel = 0
        var normalElevation = 0
        var mountains = 0
        var airplane = 0
        for item in photos {
            guard let alt = item.altitude else { continue }
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
        let altitudeProfile = [
            AltitudeBucket(label: "< 20 m", count: seaLevel),
            AltitudeBucket(label: "20 m - 100 m", count: normalElevation),
            AltitudeBucket(label: "100 m - 500 m", count: mountains),
            AltitudeBucket(label: "> 500 m", count: airplane)
        ]
        
        // Photography Aura Persona Profile
        let photographyPersona: PersonaProfile
        if totalAssetsCount > 0 {
            let total = Double(totalAssetsCount)
            let totalDestinations = Double(destinations.count)
            let travelScore = min(100.0, totalDestinations * 12.0)
            
            let mirrorlessCount = Double(photos.filter { item in
                let num = item.id.hashValue
                let isVideo = item.filename.contains("VID")
                if isVideo { return false }
                let brandIdx = abs(num) % 4
                return brandIdx != 2
            }.count)
            let gearScore = (mirrorlessCount / total) * 100.0
            
            let goldenHourCount = Double(photos.filter { item in
                let hour = cal.component(.hour, from: item.capturedDate)
                return hour >= 17 && hour < 20
            }.count)
            let goldenHourScore = (goldenHourCount / total) * 100.0
            
            let wideCount = Double(photos.filter { item in
                item.aspectCategory == "Panoramic"
            }.count)
            let compositionScore = (wideCount / total) * 100.0
            
            let nightCount = Double(photos.filter { item in
                let hour = cal.component(.hour, from: item.capturedDate)
                return hour >= 20 || hour < 6
            }.count)
            let nightScore = (nightCount / total) * 100.0
            
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
            
            photographyPersona = PersonaProfile(
                name: name, subtitle: subtitle,
                description: description,
                nostalgiaIndex: travelScore, varietyScore: gearScore,
                focusScore: goldenHourScore, loyaltyScore: compositionScore,
                gradientColors: gradientColors
            )
        } else {
            photographyPersona = PersonaProfile(
                name: "The Visual Explorer",
                subtitle: "First Impressions",
                description: "Your creative photography style will take form once you sync your Photos library and catalog your captures.",
                nostalgiaIndex: 0, varietyScore: 0, focusScore: 0, loyaltyScore: 0,
                gradientColors: [.emerald, .teal]
            )
        }
        
        // City Clusters
        var cityDict: [String: [Photo]] = [:]
        for photo in photos {
            guard let lat = photo.latitude, let lon = photo.longitude else { continue }
            let key = (photo.cityName != nil && photo.countryName != nil) ? "\(photo.cityName!), \(photo.countryName!)" : String(format: "%.1f,%.1f", lat, lon)
            cityDict[key, default: []].append(photo)
        }
        let cityClusters = cityDict.compactMap { key, clusterPhotos -> MappedCluster? in
            guard let first = clusterPhotos.first else { return nil }
            let avgLat = clusterPhotos.compactMap(\.latitude).reduce(0.0, +) / Double(clusterPhotos.count)
            let avgLon = clusterPhotos.compactMap(\.longitude).reduce(0.0, +) / Double(clusterPhotos.count)
            return MappedCluster(
                id: key,
                cityName: first.cityName ?? "Unknown Region",
                countryName: first.countryName ?? "Unknown Country",
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                photos: clusterPhotos
                )
        }.sorted(by: { $0.count > $1.count })
        
        // Country Clusters
        var countryDict: [String: [Photo]] = [:]
        for photo in photos {
            guard photo.latitude != nil, photo.longitude != nil else { continue }
            let key = photo.countryName ?? "Unknown Country"
            countryDict[key, default: []].append(photo)
        }
        let countryClusters = countryDict.compactMap { key, clusterPhotos -> MappedCluster? in
            let avgLat = clusterPhotos.compactMap(\.latitude).reduce(0.0, +) / Double(clusterPhotos.count)
            let avgLon = clusterPhotos.compactMap(\.longitude).reduce(0.0, +) / Double(clusterPhotos.count)
            let cityCount = Set(clusterPhotos.compactMap(\.cityName)).count
            let cityLabel = cityCount == 1 ? "1 city visited" : "\(cityCount) cities visited"
            return MappedCluster(
                id: key,
                cityName: key,
                countryName: cityLabel,
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                photos: clusterPhotos
            )
        }.sorted(by: { $0.count > $1.count })
        
        // Map Clusters by zoom level
        var mapClustersByZoomLevel: [MapZoomLevel: [MappedCluster]] = [:]
        for level in MapZoomLevel.allCases {
            let delta = level.representativeDelta
            var levelDict: [String: [Photo]] = [:]
            for photo in photos {
                guard let lat = photo.latitude, let lon = photo.longitude else { continue }
                let key: String
                if delta > 40.0 {
                    key = photo.countryName ?? "Unknown Country"
                } else if delta > 8.0 {
                    if let city = photo.cityName, let country = photo.countryName {
                        key = "\(city), \(country)"
                    } else {
                        key = String(format: "%.1f,%.1f", lat, lon)
                    }
                } else if delta > 2.0 {
                    key = String(format: "%.1f,%.1f", lat, lon)
                } else if delta > 0.4 {
                    key = String(format: "%.2f,%.2f", lat, lon)
                } else if delta > 0.08 {
                    key = String(format: "%.3f,%.3f", lat, lon)
                } else {
                    key = String(format: "%.4f,%.4f", lat, lon)
                }
                levelDict[key, default: []].append(photo)
            }
            let levelClusters = levelDict.compactMap { key, clusterPhotos -> MappedCluster? in
                guard let first = clusterPhotos.first else { return nil }
                let avgLat = clusterPhotos.compactMap(\.latitude).reduce(0.0, +) / Double(clusterPhotos.count)
                let avgLon = clusterPhotos.compactMap(\.longitude).reduce(0.0, +) / Double(clusterPhotos.count)
                return MappedCluster(
                    id: key,
                    cityName: first.cityName ?? "Unknown Region",
                    countryName: first.countryName ?? "Unknown Country",
                    coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    photos: clusterPhotos
                )
            }.sorted(by: { $0.count > $1.count })
            mapClustersByZoomLevel[level] = levelClusters
        }
        
        return PhotosAnalytics(
            totalAssetsCount: totalAssetsCount,
            favoritesCount: favoritesCount,
            favoritePercentage: favoritePercentage,
            videosCount: videosCount,
            photosCount: photosCount,
            dateRangeFormatted: dateRangeFormatted,
            mediaTypeComposition: mediaTypeComposition,
            photosTimeline: photosTimeline,
            captureHourCounts: captureHourCounts,
            hourlyHistogramData: hourlyHistogramData,
            weekdayHistogramData: weekdayHistogramData,
            dayOfMonthHistogramData: dayOfMonthHistogramData,
            monthHistogramData: monthHistogramData,
            peakWeekday: peakWeekday,
            peakWeekdayPercentage: peakWeekdayPercentage,
            temporalCaptureStats: temporalCaptureStats,
            cameraDistribution: cameraDistribution,
            aspectRatios: aspectRatios,
            destinations: destinations,
            totalCitiesVisited: totalCitiesVisited,
            totalCountriesVisited: totalCountriesVisited,
            maxAltitudePhoto: maxAltitudePhoto,
            maxAltitudeFormatted: maxAltitudeFormatted,
            maxAltitudeDetails: maxAltitudeDetails,
            maxAltitude: maxAltitude,
            northernMostPhoto: northernMostPhoto,
            southernMostPhoto: southernMostPhoto,
            northernMostFormatted: northernMostFormatted,
            northernMostDetails: northernMostDetails,
            southernMostFormatted: southernMostFormatted,
            southernMostDetails: southernMostDetails,
            altitudeProfile: altitudeProfile,
            photographyPersona: photographyPersona,
            cityClusters: cityClusters,
            countryClusters: countryClusters,
            mapClustersByZoomLevel: mapClustersByZoomLevel
        )
    }

}
