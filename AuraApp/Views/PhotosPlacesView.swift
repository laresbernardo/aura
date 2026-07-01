import SwiftUI
import Charts

struct PhotosPlacesView: View {
    @ObservedObject var manager: PhotosLibraryManager
    
    @State private var hoveredBucketLabel: String? = nil
    
    enum DestinationGrouping: String, CaseIterable, Identifiable {
        case city = "City"
        case country = "Country"
        
        var id: String { rawValue }
    }
    
    struct GroupedDestination: Identifiable {
        let id = UUID()
        let name: String
        let subname: String
        let count: Int
    }
    
    @State private var destinationGrouping: DestinationGrouping = .city
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Places")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Geographical footprints of your photography, travel destinations, and altitude elevations.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if manager.pendingGeocodeCount > 0 {
                    HStack(spacing: 12) {
                        if manager.isGeocoding {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.emerald)
                            Text("Analyzing travel places in the background... (\(manager.pendingGeocodeCount) locations remaining)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.emerald)
                        } else {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            Text("Travel analysis paused (\(manager.pendingGeocodeCount) locations remaining)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            manager.toggleGeocodingPause()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: manager.isGeocoding ? "pause.fill" : "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text(manager.isGeocoding ? "Pause" : "Resume")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(manager.isGeocoding ? Color.emerald.opacity(0.08) : Color.orange.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(manager.isGeocoding ? Color.emerald.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: manager.isGeocoding)
                }
                
                // MARK: - Places KPIs
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 20) {
                    // KPI 1: Total Countries
                    PhotosMetricCard(
                        title: "Countries Visited",
                        value: "\(manager.totalCountriesVisited.formatted()) Countries",
                        subtitle: "Across \(manager.totalCitiesVisited.formatted()) distinct cities",
                        icon: "globe.americas.fill",
                        gradient: LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // /Users/bernardo/Library/CloudStorage/GoogleDrive-laresbernardo@gmail.com/My Drive/Documentos/Antigravity/Aura/AuraApp/Views/PhotosPlacesView.swift
                    // KPI 2: Max Elevation
                    PhotosMetricCard(
                        title: "Maximum Altitude",
                        value: manager.maxAltitudeFormatted,
                        subtitle: manager.maxAltitudeDetails,
                        icon: "mountain.2.fill",
                        gradient: LinearGradient(colors: [.emerald, .teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                        action: manager.sourceMode == .direct ? {
                            if let photo = manager.maxAltitudePhoto {
                                manager.revealPhotoInPhotosApp(photoId: photo.id)
                            }
                        } : nil,
                        photo: manager.maxAltitudePhoto,
                        sourceMode: manager.sourceMode
                    )
                    
                    // KPI 3: Northern-most Photo
                    PhotosMetricCard(
                        title: "Northern-most Photo",
                        value: manager.northernMostFormatted,
                        subtitle: manager.northernMostDetails,
                        icon: "arrow.up.circle.fill",
                        gradient: LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        action: manager.sourceMode == .direct ? {
                            if let photo = manager.northernMostPhoto {
                                manager.revealPhotoInPhotosApp(photoId: photo.id)
                            }
                        } : nil,
                        photo: manager.northernMostPhoto,
                        sourceMode: manager.sourceMode
                    )
                    
                    // KPI 4: Southern-most Photo
                    PhotosMetricCard(
                        title: "Southern-most Photo",
                        value: manager.southernMostFormatted,
                        subtitle: manager.southernMostDetails,
                        icon: "arrow.down.circle.fill",
                        gradient: LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        action: manager.sourceMode == .direct ? {
                            if let photo = manager.southernMostPhoto {
                                manager.revealPhotoInPhotosApp(photoId: photo.id)
                            }
                        } : nil,
                        photo: manager.southernMostPhoto,
                        sourceMode: manager.sourceMode
                    )
                }
                
                // MARK: - Destinations and Altitude Layout
                HStack(alignment: .top, spacing: 24) {
                    // Destinations Table Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Travel Destinations")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Catalog of cities and country regions visited")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Picker("Group By", selection: $destinationGrouping) {
                                    ForEach(DestinationGrouping.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .frame(width: 150)
                            }
                            
                            Divider().background(Color.white.opacity(0.06))
                            
                            if manager.destinations.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No geocoded place metadata found.")
                                        .foregroundColor(.secondary)
                                        .padding()
                                    Spacer()
                                }
                                .frame(height: 200)
                            } else {
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(spacing: 12) {
                                        ForEach(groupedDestinations) { stat in
                                            HStack(spacing: 12) {
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.emerald.opacity(0.12))
                                                        .frame(width: 32, height: 32)
                                                    
                                                    Image(systemName: "mappin.circle.fill")
                                                        .foregroundColor(.emerald)
                                                        .font(.system(size: 14))
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("\(stat.name)")
                                                        .font(.system(.body, design: .rounded))
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white.opacity(0.95))
                                                    Text(stat.subname)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Text("\(stat.count.formatted()) shots")
                                                    .font(.system(.caption, design: .monospaced))
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.emerald)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.emerald.opacity(0.08))
                                                    .cornerRadius(6)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 240)
                            }
                        }
                        .padding(24)
                    }
                    .glassCardHoverEffect()
                    
                    // Elevation/Altitude Profile Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Altitude Elevation Profile")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Distribution of photo elevations")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if manager.altitudeProfile.isEmpty {
                                Text("No altitude data found.")
                                    .foregroundColor(.secondary)
                                    .frame(height: 220)
                            } else {
                                Chart(manager.altitudeProfile) { bucket in
                                    BarMark(
                                        x: .value("Bucket", bucket.label),
                                        y: .value("Photos", bucket.count)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.cyan.opacity(0.85), .blue.opacity(0.35)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(4)
                                    .annotation(position: .top) {
                                        if hoveredBucketLabel == bucket.label && bucket.count > 0 {
                                            Text(bucket.count.formatted())
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.blue.opacity(0.85))
                                                .cornerRadius(4)
                                                .offset(y: -4)
                                        }
                                    }
                                }
                                .chartOverlay { proxy in
                                    GeometryReader { geo in
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                            .onContinuousHover { phase in
                                                switch phase {
                                                case .active(let location):
                                                    if let bucket: String = proxy.value(atX: location.x) {
                                                        hoveredBucketLabel = bucket
                                                    } else {
                                                        hoveredBucketLabel = nil
                                                    }
                                                case .ended:
                                                    hoveredBucketLabel = nil
                                                }
                                            }
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
                                        AxisValueLabel()
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks { value in
                                        AxisValueLabel()
                                            .foregroundStyle(.white.opacity(0.85))
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    }
                                }
                                .chartXScale(domain: manager.altitudeProfileLabels)
                                .frame(height: 200)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(24)
                    }
                    .glassCardHoverEffect()
                }
            }
            .padding(4)
        }
    }
    
    // MARK: - Places Helpers
    private var groupedDestinations: [GroupedDestination] {
        if destinationGrouping == .city {
            return manager.destinations.map {
                GroupedDestination(
                    name: $0.city,
                    subname: $0.country,
                    count: $0.count
                )
            }
        } else {
            // Group by country
            var countryCounts: [String: (shots: Int, cities: Set<String>)] = [:]
            for dest in manager.destinations {
                if var existing = countryCounts[dest.country] {
                    existing.shots += dest.count
                    existing.cities.insert(dest.city)
                    countryCounts[dest.country] = existing
                } else {
                    countryCounts[dest.country] = (shots: dest.count, cities: [dest.city])
                }
            }
            return countryCounts.map { country, data in
                let cityCount = data.cities.count
                let cityLabel = cityCount == 1 ? "1 city visited" : "\(cityCount) cities visited"
                return GroupedDestination(
                    name: country,
                    subname: cityLabel,
                    count: data.shots
                )
            }.sorted(by: { $0.count > $1.count })
        }
    }
}
