import SwiftUI
import Charts

struct OverviewDashboardView: View {
    @ObservedObject var manager: MusicLibraryManager
    @State private var selectedGenre: GenreStat?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overview Dashboard")
                        .font(.system(.title1, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("High-level library metrics, composition trends, and listening totals.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - KPI Metric Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    // Metric 1: Total Tracks
                    MetricCard(
                        title: "Total Tracks",
                        value: "\(manager.totalTracks)",
                        subtitle: "Items in Library",
                        icon: "music.note.list",
                        gradient: LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // Metric 2: Total Listening Time
                    MetricCard(
                        title: "Listening Time",
                        value: manager.totalListeningTimeFormatted,
                        subtitle: "Estimated playback",
                        icon: "clock.fill",
                        gradient: LinearGradient(colors: [Color.purple, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // Metric 3: Top Artist
                    MetricCard(
                        title: "Top Artist",
                        value: manager.topArtist,
                        subtitle: "By cumulative plays",
                        icon: "person.wave.2.fill",
                        gradient: LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // Metric 4: Top Genre (Bonus Metric)
                    MetricCard(
                        title: "Primary Genre",
                        value: manager.topGenre,
                        subtitle: "Most popular style",
                        icon: "tag.fill",
                        gradient: LinearGradient(colors: [Color.emerald, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                
                // MARK: - Library Genre Composition Chart
                GlassCard {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Library Composition")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Distribution of tracks by music genre")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Text("\(manager.genreDistribution.count) Genres")
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                        }
                        
                        if manager.genreDistribution.isEmpty {
                            HStack {
                                Spacer()
                                Text("No genre data available. Sync your library.")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                            .frame(height: 220)
                        } else {
                            HStack(spacing: 30) {
                                // Native Swift Chart
                                Chart(manager.genreDistribution) { stat in
                                    BarMark(
                                        x: .value("Count", stat.count),
                                        y: .value("Genre", stat.genre)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [genreColor(for: stat.genre).opacity(0.9), genreColor(for: stat.genre).opacity(0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(5)
                                    .annotation(position: .trailing) {
                                        Text("\(stat.count)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel()
                                            .foregroundStyle(.white.opacity(0.8))
                                            .font(.caption)
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks { value in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                        AxisValueLabel()
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 9, design: .monospaced))
                                    }
                                }
                                .frame(height: 260)
                                .padding(.vertical, 10)
                                
                                // Custom Side Legend List
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Genre Details")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.bottom, 4)
                                    
                                    ScrollView(.vertical, showsIndicators: false) {
                                        VStack(spacing: 10) {
                                            ForEach(manager.genreDistribution.prefix(6)) { stat in
                                                HStack(spacing: 10) {
                                                    Circle()
                                                        .fill(genreColor(for: stat.genre))
                                                        .frame(width: 8, height: 8)
                                                    
                                                    Text(stat.genre)
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.85))
                                                    
                                                    Spacer()
                                                    
                                                    Text(String(format: "%.1f%%", stat.percentage))
                                                        .font(.system(.caption2, design: .monospaced))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .frame(width: 160, height: 180)
                                }
                            }
                        }
                    }
                    .padding(24)
                }
                .glassCardHoverEffect()
            }
            .padding(4)
        }
    }
    
    // Helper: Dynamic Premium Colors for Genres
    private func genreColor(for genre: String) -> Color {
        switch genre.lowercased() {
        case "synthwave": return Color.purple
        case "indie rock", "rock": return Color.cyan
        case "lofi house", "house": return Color.orange
        case "orchestral", "soundtrack": return Color.pink
        case "dark jazz", "jazz": return Color.yellow
        case "dreampop", "shoegaze", "pop": return Color.teal
        default: return Color.gray
        }
    }
}

// MARK: - Custom KPI Metric Card
struct MetricCard: View {
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
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(gradient)
                        .scaleEffect(isHovered ? 1.2 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isHovered)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
        }
        .glassCardHoverEffect(cornerRadius: 14)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Custom Emerald Color for matching premium dashboard palettes
extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
}
