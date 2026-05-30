import SwiftUI
import Charts

struct ListeningHabitsView: View {
    @ObservedObject var manager: MusicLibraryManager
    @State private var selectedTrack: Track?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Listening Habits")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Behavioral insights mapping engagement vs. fatigue, and discovering hidden gems.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Interactive Play vs Skip Scatter Plot
                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anthems vs. Song Fatigue")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Plots your top 150 most active tracks based on adaptive play and skip thresholds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 24) {
                            // The Scatter Plot
                            VStack {
                                Chart(scatterPlotTracks) { track in
                                    PointMark(
                                        x: .value("Play Count", track.playCount),
                                        y: .value("Skip Count", track.skipCount)
                                    )
                                    .symbol(symbol(for: track))
                                    .symbolSize(selectedTrack?.id == track.id ? 140 : 55)
                                    .foregroundStyle(
                                        selectedTrack?.id == track.id
                                            ? Color.yellow
                                            : habitColor(for: track)
                                    )
                                }
                                .chartXAxis {
                                    AxisMarks { value in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                        AxisValueLabel("Plays")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 9, design: .monospaced))
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                        AxisValueLabel("Skips")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 9, design: .monospaced))
                                    }
                                }
                                // Adding tap selection capability
                                .chartOverlay { proxy in
                                    GeometryReader { geo in
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                            .onTapGesture(count: 1) { location in
                                                updateSelectedTrack(at: location, proxy: proxy, geometry: geo)
                                            }
                                    }
                                }
                                .frame(height: 280)
                                
                                // X & Y Axis Titles
                                Text("Horizontal: Play Count  •  Vertical: Skip Count")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Dynamic Interaction Panel
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Behaviors Legend")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    LegendRow(color: .emerald, icon: "star.fill", label: "Unskippable Anthems", desc: "Plays ≥ \(dynamicThresholds.play), Skips < \(dynamicThresholds.skip)")
                                    LegendRow(color: .orange, icon: "exclamationmark.triangle.fill", label: "Song Fatigue", desc: "Plays ≥ \(dynamicThresholds.play), Skips ≥ \(dynamicThresholds.skip)")
                                    LegendRow(color: .red, icon: "gobackward", label: "Skipped/Disliked", desc: "Plays < \(dynamicThresholds.play), Skips ≥ \(dynamicThresholds.skip)")
                                    LegendRow(color: .blue, icon: "circle.fill", label: "Standard Rotation", desc: "Moderate Playback")
                                }
                                .padding(.bottom, 6)
                                
                                // Selected Track Card
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Selected Node Details")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    if let selected = selectedTrack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(selected.name)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            
                                            Text(selected.artist)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                            
                                            HStack(spacing: 12) {
                                                Text("Plays: \(selected.playCount)")
                                                Text("Skips: \(selected.skipCount)")
                                            }
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.8))
                                            
                                            HStack {
                                                Text(behaviorCategory(for: selected))
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(habitColor(for: selected))
                                                    .cornerRadius(4)
                                                
                                                Spacer()
                                                
                                                StarsView(stars: selected.ratingStars)
                                            }
                                            .padding(.top, 2)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.06))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                                        )
                                    } else {
                                        VStack {
                                            Spacer()
                                            Text("Click any point on the plot to inspect the track.")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 95)
                                        .background(Color.white.opacity(0.03))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .frame(width: 240)
                        }
                    }
                    .padding(24)
                }
                .glassCardHoverEffect()
                
                // MARK: - Forgotten Gems Section
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("Forgotten Gems")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text("Tracks rated 4-5 stars that you haven't played in over 2 years. Rediscover them!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if manager.forgottenGems.isEmpty {
                            HStack {
                                Spacer()
                                Text("No forgotten gems found. All your favorites are in regular rotation!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 24)
                                Spacer()
                            }
                        } else {
                            VStack(spacing: 0) {
                                // Header
                                TableHeaderRow()
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                // Scrollable List
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(spacing: 0) {
                                        ForEach(manager.forgottenGems.prefix(15)) { track in
                                            TableRowView(track: track)
                                            Divider().background(Color.white.opacity(0.04))
                                        }
                                    }
                                }
                                .frame(height: 260)
                            }
                        }
                    }
                    .padding(24)
                }
                .glassCardHoverEffect()
                
                // MARK: - Love-Hate Paradox (Nostalgic Burnout)
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "heart.slash.fill")
                                    .foregroundColor(.red)
                                Text("The Love-Hate Paradox")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text("Tracks you love (high rating or plays) but skip frequently. Is it nostalgic burnout?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if manager.loveHateParadox.isEmpty {
                            HStack {
                                Spacer()
                                Text("No love-hate conflicts. Your favorite tracks remain unskipped!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 24)
                                Spacer()
                            }
                        } else {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Track Info")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("Genre")
                                        .frame(width: 100, alignment: .leading)
                                    Text("Rating")
                                        .frame(width: 80, alignment: .center)
                                    Text("Skips")
                                        .frame(width: 130, alignment: .trailing)
                                }
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.02))
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                ScrollView(.vertical, showsIndicators: false) {
                                    VStack(spacing: 0) {
                                        ForEach(manager.loveHateParadox.prefix(15)) { track in
                                            LoveHateRowView(track: track)
                                            Divider().background(Color.white.opacity(0.04))
                                        }
                                    }
                                }
                                .frame(height: 260)
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
    
    // MARK: - Quadrant & Categorization Helpers
    
    private var scatterPlotTracks: [Track] {
        let active = manager.tracks.filter { $0.playCount > 0 || $0.skipCount > 0 }
        return Array(active.sorted(by: { ($0.playCount + $0.skipCount) > ($1.playCount + $1.skipCount) }).prefix(150))
    }
    
    private var dynamicThresholds: (play: Int, skip: Int) {
        let plays = manager.tracks.map { $0.playCount }
        let skips = manager.tracks.map { $0.skipCount }
        let maxPlay = plays.max() ?? 100
        let maxSkip = skips.max() ?? 20
        
        let sortedPlays = plays.sorted()
        let percentilePlay = sortedPlays.isEmpty ? 10 : sortedPlays[Int(Double(sortedPlays.count) * 0.85)]
        let playThreshold = max(10, min(percentilePlay, maxPlay / 3))
        
        let sortedSkips = skips.sorted()
        let percentileSkip = sortedSkips.isEmpty ? 3 : sortedSkips[Int(Double(sortedSkips.count) * 0.85)]
        let skipThreshold = max(3, min(percentileSkip, maxSkip / 3))
        
        return (playThreshold, skipThreshold)
    }
    
    private func habitColor(for track: Track) -> Color {
        let thresholds = dynamicThresholds
        if track.playCount >= thresholds.play && track.skipCount < thresholds.skip {
            return .emerald // Unskippable Anthem
        } else if track.playCount >= thresholds.play && track.skipCount >= thresholds.skip {
            return .orange // Song Fatigue
        } else if track.playCount < thresholds.play && track.skipCount >= thresholds.skip {
            return .red // Skipped / Disliked
        } else {
            return .blue // Standard Rotation
        }
    }
    
    private func symbol(for track: Track) -> BasicChartSymbolShape {
        let thresholds = dynamicThresholds
        if track.playCount >= thresholds.play && track.skipCount < thresholds.skip {
            return .square
        } else if track.playCount >= thresholds.play && track.skipCount >= thresholds.skip {
            return .triangle
        } else if track.playCount < thresholds.play && track.skipCount >= thresholds.skip {
            return .diamond
        } else {
            return .circle
        }
    }
    
    private func behaviorCategory(for track: Track) -> String {
        let thresholds = dynamicThresholds
        if track.playCount >= thresholds.play && track.skipCount < thresholds.skip {
            return "ANTHEM"
        } else if track.playCount >= thresholds.play && track.skipCount >= thresholds.skip {
            return "FATIGUE"
        } else if track.playCount < thresholds.play && track.skipCount >= thresholds.skip {
            return "DISLIKED"
        } else {
            return "STANDARD"
        }
    }
    
    // Tap Coordinate Interaction
    private func updateSelectedTrack(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        // Find corresponding values in the chart using proxy coordinate conversion
        guard let playCountVal: Int = proxy.value(atX: location.x),
              let skipCountVal: Int = proxy.value(atY: location.y) else { return }
        
        // Find track closest to this play and skip count coordinates (searching only from our active display subset)
        let sorted = scatterPlotTracks.sorted { t1, t2 in
            let d1 = pow(Double(t1.playCount - playCountVal), 2) + pow(Double(t1.skipCount - skipCountVal), 2)
            let d2 = pow(Double(t2.playCount - playCountVal), 2) + pow(Double(t2.skipCount - skipCountVal), 2)
            return d1 < d2
        }
        
        if let closest = sorted.first {
            let distance = sqrt(pow(Double(closest.playCount - playCountVal), 2) + pow(Double(closest.skipCount - skipCountVal), 2))
            // Set selection tolerance
            if distance < 35 {
                selectedTrack = closest
            }
        }
    }
}

// MARK: - Helper Stars View
struct StarsView: View {
    let stars: Int
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { idx in
                Image(systemName: idx <= stars ? "star.fill" : "star")
                    .font(.system(size: 9))
                    .foregroundColor(idx <= stars ? .yellow : .white.opacity(0.15))
            }
        }
    }
}

// MARK: - Legend Row Helper
struct LegendRow: View {
    let color: Color
    let icon: String
    let label: String
    let desc: String
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Table Helpers
struct TableHeaderRow: View {
    var body: some View {
        HStack {
            Text("Track Info")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Genre")
                .frame(width: 100, alignment: .leading)
            Text("Stars")
                .frame(width: 80, alignment: .center)
            Text("Last Played")
                .frame(width: 130, alignment: .trailing)
        }
        .font(.caption)
        .fontWeight(.bold)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
    }
}

struct TableRowView: View {
    let track: Track
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(track.genre)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            StarsView(stars: track.ratingStars)
                .frame(width: 80, alignment: .center)
            
            Text(lastPlayedFormatted)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private var lastPlayedFormatted: String {
        guard let lastPlayedDate = track.lastPlayedDate else { return "Never" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: lastPlayedDate)
    }
}

struct LoveHateRowView: View {
    let track: Track
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(track.genre)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            HStack(spacing: 4) {
                StarsView(stars: track.ratingStars)
                if track.ratingStars == 0 {
                    Text("Plays: \(track.playCount)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, alignment: .center)
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.forward.to.line.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 8))
                Text("\(track.skipCount) skips")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
            .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
