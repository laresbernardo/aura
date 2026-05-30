import SwiftUI
import Charts

struct PhotosPlacesView: View {
    @ObservedObject var manager: PhotosLibraryManager
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Places & Journeys")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Geographical footprints of your photography, travel destinations, and altitude elevations.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Places KPIs
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    // KPI 1: Total Countries
                    PhotosMetricCard(
                        title: "Countries Visited",
                        value: "\(manager.totalCountriesVisited) Countries",
                        subtitle: "Across \(manager.totalCitiesVisited) distinct cities",
                        icon: "globe.americas.fill",
                        gradient: LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // KPI 2: Max Elevation
                    PhotosMetricCard(
                        title: "Maximum Altitude",
                        value: String(format: "%.0f meters", manager.maxAltitude),
                        subtitle: String(format: "Approx. %.0f feet elevation", manager.maxAltitude * 3.28084),
                        icon: "mountain.2.fill",
                        gradient: LinearGradient(colors: [.emerald, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // KPI 3: Top Travel Spot
                    PhotosMetricCard(
                        title: "Top Travel Spot",
                        value: topDestinationName,
                        subtitle: "City with the most captures",
                        icon: "mappin.and.ellipse",
                        gradient: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                
                // MARK: - Destinations and Altitude Layout
                HStack(alignment: .top, spacing: 24) {
                    // Destinations Table Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Travel Destinations")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Catalog of cities and country regions visited")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                                        ForEach(manager.destinations) { stat in
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
                                                    Text("\(stat.city)")
                                                        .font(.system(.body, design: .rounded))
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white.opacity(0.95))
                                                    Text(stat.country)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Text("\(stat.count) shots")
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
                                            .font(.system(size: 8, design: .rounded))
                                    }
                                }
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
    private var topDestinationName: String {
        guard let firstDest = manager.destinations.first else { return "Unknown Spot" }
        return "\(firstDest.city), \(firstDest.country)"
    }
}
