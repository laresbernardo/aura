import SwiftUI
import Charts

struct OverviewDashboardView: View {
    @ObservedObject var manager: MusicLibraryManager
    @State private var selectedGenre: GenreStat?
    @State private var showSummary = false
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    // Header Section
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Overview Dashboard")
                                .font(.system(.title, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("High-level library metrics, composition trends, and listening totals.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showSummary = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles.rectangle.stack")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Aura Insights")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.purple.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.purple.opacity(0.35), lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("View automated library summary and behavioral insights")
                    }
                
                // MARK: - KPI Metric Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    // Metric 1: Added Tracks
                    MetricCard(
                        title: "Added Tracks",
                        value: manager.totalTracks.formatted(),
                        subtitle: "Items in Library",
                        icon: "music.note.list",
                        gradient: LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // Metric 2: Listening Time
                    MetricCard(
                        title: "Listening Time",
                        value: manager.totalListeningTimeFormatted,
                        subtitle: "Estimated playback",
                        icon: "clock.fill",
                        gradient: LinearGradient(colors: [Color.purple, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // Metric 3: Active Discovery
                    let totalAddedInFilter = manager.tracks.count
                    let activeAddedInFilter = manager.tracks.filter { $0.playCount > 0 }.count
                    let activePercentage = totalAddedInFilter > 0 ? (Double(activeAddedInFilter) / Double(totalAddedInFilter)) * 100.0 : 0.0
                    
                    MetricCard(
                        title: "Active Discovery",
                        value: String(format: "%.1f%%", activePercentage),
                        subtitle: "\(activeAddedInFilter.formatted()) of added tracks",
                        icon: "sparkles",
                        gradient: LinearGradient(colors: [Color.emerald, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // Metric 4: Final Plays
                    let cal = Calendar.current
                    let playedInPeriodCount: Int = {
                        switch manager.currentFilter {
                        case .allTime:
                            let currentYear = cal.component(.year, from: Date())
                            return manager.allTracks.filter { track in
                                guard let lastPlayed = track.lastPlayedDate else { return false }
                                return cal.component(.year, from: lastPlayed) == currentYear
                            }.count
                        case .specificYear(let year):
                            return manager.allTracks.filter { track in
                                guard let lastPlayed = track.lastPlayedDate else { return false }
                                return cal.component(.year, from: lastPlayed) == year
                            }.count
                        case .customRange:
                            let start = cal.startOfDay(for: manager.customStartDate)
                            let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: manager.customEndDate) ?? manager.customEndDate
                            return manager.allTracks.filter { track in
                                guard let lastPlayed = track.lastPlayedDate else { return false }
                                return lastPlayed >= start && lastPlayed <= end
                            }.count
                        }
                    }()
                    let totalTracksCount = manager.allTracks.count
                    let variancePercentage = totalTracksCount > 0 ? (Double(playedInPeriodCount) / Double(totalTracksCount)) * 100.0 : 0.0
                    
                    MetricCard(
                        title: "Final Plays",
                        value: String(format: "%.1f%%", variancePercentage),
                        subtitle: "\(playedInPeriodCount.formatted()) of total tracks",
                        icon: "archivebox",
                        gradient: LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                
                // MARK: - Library Composition Chart (Genres & Artists)
                GlassCard {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Library Composition")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Top genres and artists distribution")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Text("\(manager.genreDistribution.count.formatted()) Genres")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                                
                                Text("\(manager.topArtistsDetailed.count.formatted()) Artists")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                            }
                        }
                        
                        if manager.tracks.isEmpty {
                            HStack {
                                Spacer()
                                Text(manager.allTracks.isEmpty ? "No library data available. Sync your library." : "No tracks found for the selected Time Range.")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                            .frame(height: 220)
                        } else {
                            HStack(spacing: 40) {
                                // Left Half: Genres
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Top Genres")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Chart(chartGenres) { stat in
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
                                            Text(stat.count.formatted())
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
                                    .frame(height: 220)
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Right Half: Artists
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Top Artists by Tracks")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    let top5Artists = Array(manager.topArtistsDetailed
                                        .sorted(by: { $0.trackCount > $1.trackCount })
                                        .prefix(5))
                                    Chart(top5Artists) { stat in
                                        BarMark(
                                            x: .value("Tracks", stat.trackCount),
                                            y: .value("Artist", stat.artist)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.purple.opacity(0.9), .pink.opacity(0.4)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(5)
                                        .annotation(position: .trailing) {
                                            Text(stat.trackCount.formatted())
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
                                    .frame(height: 220)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(24)
                }
                .glassCardHoverEffect()
            }
            .padding(4)
            }
            
            if showSummary {
                // Dimmed background overlay
                Color.black.opacity(0.45)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            showSummary = false
                        }
                    }
                
                // Pop-up glassmorphic window
                GlassCard(cornerRadius: 20, shadowRadius: 15) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title Bar
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                Text("Aura AI Insights")
                                    .font(.system(.title3, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    showSummary = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Summary Content
                        ScrollView(.vertical, showsIndicators: true) {
                            AuraInsightsContentView(manager: manager)
                                .padding(.trailing, 8)
                        }
                        .frame(maxHeight: 320)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        // Close Button
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    showSummary = false
                                }
                            }) {
                                Text("Done")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(Color.purple)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                }
                .frame(width: 500)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
    }

    
    // Helper: Cap genres to top 5 (exclude "Others")
    private var chartGenres: [GenreStat] {
        let allGenres = manager.genreDistribution
        return Array(allGenres.prefix(5))
    }
    
    // Helper: Dynamic Premium Colors for Genres
    private func genreColor(for genre: String) -> Color {
        let g = genre.lowercased()
        if g.contains("synthwave") || g.contains("electronic") || g.contains("techno") || g.contains("dance") { return Color.purple }
        if g.contains("rock") || g.contains("indie") || g.contains("alternative") { return Color.cyan }
        if g.contains("house") || g.contains("lofi") || g.contains("chill") { return Color.orange }
        if g.contains("classical") || g.contains("orchestral") || g.contains("soundtrack") { return Color.pink }
        if g.contains("jazz") || g.contains("blues") || g.contains("soul") { return Color.yellow }
        if g.contains("pop") || g.contains("hip hop") || g.contains("rap") || g.contains("r&b") { return Color.teal }
        if g.contains("others") || g.contains("other") { return Color.gray.opacity(0.8) }
        
        let colors: [Color] = [.purple, .cyan, .orange, .pink, .yellow, .teal, .indigo, .mint]
        let index = abs(genre.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Custom KPI Metric Card
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    var action: (() -> Void)? = nil
    
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
                        .foregroundColor(isHovered && action != nil ? .purple : .white)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(18)
        }
        .glassCardHoverEffect(cornerRadius: 14)
        .onHover { hovering in
            if action != nil {
                isHovered = hovering
            }
        }
        .onTapGesture {
            if let action = action {
                action()
            }
        }
        .help(action != nil ? "Click to filter in macOS Music" : "")
    }
}

// Custom Emerald Color for matching premium dashboard palettes
extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
}

// MARK: - Automated Summary Dynamic Content Views
struct AuraInsightsContentView: View {
    @ObservedObject var manager: MusicLibraryManager
    
    var body: some View {
        let cal = Calendar.current
        let yearLabel: String = {
            switch manager.currentFilter {
            case .allTime:
                return "Across All Time"
            case .specificYear(let year):
                return "for \(year)"
            case .customRange:
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                let startStr = formatter.string(from: manager.customStartDate)
                let endStr = formatter.string(from: manager.customEndDate)
                return "from \(startStr) to \(endStr)"
            }
        }()
        
        let addedCount = manager.tracks.count
        let listeningTime = manager.totalListeningTimeFormatted
        
        // Active Discovery
        let activeCount = manager.tracks.filter { $0.playCount > 0 }.count
        let activePercent = addedCount > 0 ? (Double(activeCount) / Double(addedCount)) * 100.0 : 0.0
        let inactiveCount = addedCount - activeCount
        
        // Final Plays
        let playedInPeriodCount: Int = {
            switch manager.currentFilter {
            case .allTime:
                let currentYear = cal.component(.year, from: Date())
                return manager.allTracks.filter { track in
                    guard let lastPlayed = track.lastPlayedDate else { return false }
                    return cal.component(.year, from: lastPlayed) == currentYear
                }.count
            case .specificYear(let year):
                return manager.allTracks.filter { track in
                    guard let lastPlayed = track.lastPlayedDate else { return false }
                    return cal.component(.year, from: lastPlayed) == year
                }.count
            case .customRange:
                let start = cal.startOfDay(for: manager.customStartDate)
                let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: manager.customEndDate) ?? manager.customEndDate
                return manager.allTracks.filter { track in
                    guard let lastPlayed = track.lastPlayedDate else { return false }
                    return lastPlayed >= start && lastPlayed <= end
                }.count
            }
        }()
        let totalTracksCount = manager.allTracks.count
        let variancePercentage = totalTracksCount > 0 ? (Double(playedInPeriodCount) / Double(totalTracksCount)) * 100.0 : 0.0
        
        // Top Genres
        let topGenres = manager.genreDistribution
        
        // Top Artists (by track count)
        let sortedArtists = manager.topArtistsDetailed.sorted(by: { $0.trackCount > $1.trackCount })
        
        return VStack(alignment: .leading, spacing: 22) {
            Text("Here is the summary of your music behavior \(Text(yearLabel).fontWeight(.bold)):")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.95))
            
            // Section 1: Listening & Library Size
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("⏳")
                        .font(.system(size: 16))
                    Text("Listening Profile")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    BulletPoint(text: Text("You accumulated a total listening time of \(Text(listeningTime).fontWeight(.bold))."))
                    BulletPoint(text: Text("You expanded your music library by adding \(Text("\(addedCount.formatted()) tracks").fontWeight(.bold))."))
                }
                .padding(.leading, 24)
            }
            
            // Section 2: Playback Engagement
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("✨")
                        .font(.system(size: 16))
                    Text("Playback Engagement")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    BulletPoint(text: Text("\(Text("Active Discovery").fontWeight(.bold)) registered at \(Text(String(format: "%.1f%%", activePercent)).fontWeight(.bold)). Out of the \(addedCount.formatted()) tracks you added, you played \(Text(activeCount.formatted()).fontWeight(.bold)) of them at least once. Only \(Text(inactiveCount.formatted()).fontWeight(.bold)) songs remain unplayed."))
                    
                    switch manager.currentFilter {
                    case .specificYear:
                        BulletPoint(text: Text("\(Text("Final Plays").fontWeight(.bold)) was at \(Text(String(format: "%.1f%%", variancePercentage)).fontWeight(.bold)). During this year, \(Text("\(playedInPeriodCount.formatted()) tracks").fontWeight(.bold)) had their final recorded play in your entire music history, representing your active rotation and musical transitions for the year."))
                    case .customRange:
                        BulletPoint(text: Text("\(Text("Final Plays").fontWeight(.bold)) was at \(Text(String(format: "%.1f%%", variancePercentage)).fontWeight(.bold)). During this selected period, \(Text("\(playedInPeriodCount.formatted()) tracks").fontWeight(.bold)) had their final recorded play in your entire music history, representing your active rotation and musical transitions."))
                    case .allTime:
                        BulletPoint(text: Text("\(Text("Library Rotation:").fontWeight(.bold)) Across all time, \(Text(String(format: "%.1f%%", variancePercentage)).fontWeight(.bold)) of your entire library (\(Text("\(playedInPeriodCount.formatted()) tracks").fontWeight(.bold)) tracks) had their last play recorded in the current year, indicating they remain part of your recent rotation."))
                    }
                }
                .padding(.leading, 24)
            }
            
            // Section 3: Sound Landscape
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("🎵")
                        .font(.system(size: 16))
                    Text("Sound Landscape")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    if !topGenres.isEmpty {
                        let first = topGenres[0]
                        let combinedText: Text = {
                            if topGenres.count > 1 {
                                let second = topGenres[1]
                                return Text("Your library was dominated by the genre \(Text("\"\(first.genre)\"").fontWeight(.bold)) with \(Text(first.count.formatted()).fontWeight(.bold)) tracks (\(String(format: "%.1f%%", first.percentage)) of added music). It was followed by \(Text("\"\(second.genre)\"").fontWeight(.bold)) with \(Text(second.count.formatted()).fontWeight(.bold)) tracks.")
                            } else {
                                return Text("Your library was dominated by the genre \(Text("\"\(first.genre)\"").fontWeight(.bold)) with \(Text(first.count.formatted()).fontWeight(.bold)) tracks (\(String(format: "%.1f%%", first.percentage)) of added music).")
                            }
                        }()
                        BulletPoint(text: combinedText)
                    }
                    
                    if let topArtist = sortedArtists.first, topArtist.trackCount > 0 {
                        let combinedArtistText: Text = {
                            if sortedArtists.count > 1 {
                                let second = sortedArtists[1]
                                return Text("Your top artist by volume was \(Text("\"\(topArtist.artist)\"").fontWeight(.bold)) with \(Text(topArtist.trackCount.formatted()).fontWeight(.bold)) tracks added. \(Text("\"\(second.artist)\"").fontWeight(.bold)) followed with \(Text(second.trackCount.formatted()).fontWeight(.bold)) tracks.")
                            } else {
                                return Text("Your top artist by volume was \(Text("\"\(topArtist.artist)\"").fontWeight(.bold)) with \(Text(topArtist.trackCount.formatted()).fontWeight(.bold)) tracks added.")
                            }
                        }()
                        BulletPoint(text: combinedArtistText)
                    }
                    
                    if manager.topArtist != "No Music" && !manager.topArtist.isEmpty {
                        BulletPoint(text: Text("In terms of listening duration, \(Text("\"\(manager.topArtist)\"").fontWeight(.bold)) was your most played artist, logging an estimated play duration of \(Text(manager.topArtistListeningTimeFormatted).fontWeight(.bold))."))
                    }
                }
                .padding(.leading, 24)
            }
        }
    }
}

struct BulletPoint: View {
    let text: Text
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.purple)
                .font(.system(size: 14, weight: .bold))
            text
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
        }
    }
}
