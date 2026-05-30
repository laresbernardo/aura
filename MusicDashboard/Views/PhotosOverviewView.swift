import SwiftUI
import Charts

struct PhotosOverviewView: View {
    @ObservedObject var manager: PhotosLibraryManager
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Photos Overview")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("High-level photography metrics, asset composition, and historical timelines.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if manager.isGeocoding && manager.pendingGeocodeCount > 0 {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.emerald)
                        Text("Analyzing travel places in the background... (\(manager.pendingGeocodeCount) locations remaining)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.emerald)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.emerald.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.emerald.opacity(0.2), lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: manager.isGeocoding)
                }
                
                // MARK: - KPI Metric Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    // KPI 1: Total Assets
                    PhotosMetricCard(
                        title: "Total Assets",
                        value: "\(manager.totalAssetsCount)",
                        subtitle: "\(manager.photosCount) Photos • \(manager.videosCount) Videos",
                        icon: "photo.stack.fill",
                        gradient: LinearGradient(colors: [.emerald, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // KPI 2: Favorite Ratio
                    PhotosMetricCard(
                        title: "Curated Favorites",
                        value: String(format: "%.1f%%", manager.favoritePercentage),
                        subtitle: "\(manager.favoritesCount) Starred captures",
                        icon: "heart.fill",
                        gradient: LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // KPI 3: Capture Window
                    PhotosMetricCard(
                        title: "Capture History",
                        value: manager.dateRangeFormatted,
                        subtitle: "Active catalog range",
                        icon: "calendar",
                        gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // KPI 4: Destinations Visited
                    PhotosMetricCard(
                        title: "Places Cataloged",
                        value: "\(manager.totalCitiesVisited) Cities",
                        subtitle: "Across \(manager.totalCountriesVisited) Countries",
                        icon: "globe.americas.fill",
                        gradient: LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                
                // MARK: - Charts Row
                HStack(spacing: 24) {
                    // Chart 1: Media Formats
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Asset Formats")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Breakdown by media capturing styles")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if manager.mediaTypeComposition.isEmpty {
                                Text("No asset types detected.")
                                    .foregroundColor(.secondary)
                                    .frame(height: 200)
                            } else {
                                Chart(manager.mediaTypeComposition) { stat in
                                    BarMark(
                                        x: .value("Percentage", stat.percentage),
                                        y: .value("Format", stat.genre)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [formatColor(for: stat.genre).opacity(0.9), formatColor(for: stat.genre).opacity(0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(6)
                                    .annotation(position: .trailing) {
                                        Text(String(format: "%.1f%%", stat.percentage))
                                            .font(.system(.caption2, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                                .chartXAxis(.hidden)
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel()
                                            .foregroundStyle(.white.opacity(0.85))
                                            .font(.caption)
                                    }
                                }
                                .frame(height: 160)
                                .padding(.vertical, 8)
                            }
                            
                            // Custom Legend
                            VStack(spacing: 8) {
                                ForEach(manager.mediaTypeComposition) { stat in
                                    HStack {
                                        Circle()
                                            .fill(formatColor(for: stat.genre))
                                            .frame(width: 8, height: 8)
                                        Text(stat.genre)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(stat.count) files")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(24)
                    }
                    .frame(width: 320)
                    .glassCardHoverEffect()
                    
                    // Chart 2: Monthly Timeline Growth
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Capture Growth")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Monthly count of photos & videos added over time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if manager.photosTimeline.isEmpty {
                                Text("No timeline data found.")
                                    .foregroundColor(.secondary)
                                    .frame(height: 200)
                            } else {
                                Chart(manager.photosTimeline.suffix(24)) { stat in
                                    BarMark(
                                        x: .value("Month", stat.monthYearString),
                                        y: .value("Captures", stat.count)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.emerald.opacity(0.85), .teal.opacity(0.35)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(3)
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
                                            .foregroundStyle(.white.opacity(0.8))
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
    
    private func formatColor(for format: String) -> Color {
        switch format {
        case "Still Photos": return .emerald
        case "Videos": return .cyan
        case "Live Photos": return .pink
        default: return .purple
        }
    }
}

// MARK: - Reusable Photos KPI Metric Card
struct PhotosMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    
    @State private var isHovered = false
    
    var body: some View {
        GlassCard(cornerRadius: 14, shadowRadius: 8) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(gradient)
                        .scaleEffect(isHovered ? 1.2 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isHovered)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 9.5, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 14)
        }
        .glassCardHoverEffect(cornerRadius: 14)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
