import SwiftUI
import Charts

struct ListeningHabitsView: View {
    @ObservedObject var manager: MusicLibraryManager
    @State private var selectedTrack: Track?
    
    @State private var isDetailTitleHovered = false
    @State private var isDetailArtistHovered = false
    
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
                                                .foregroundColor(isDetailTitleHovered ? .purple : .white)
                                                .lineLimit(1)
                                                .onHover { isDetailTitleHovered = $0 }
                                                .onTapGesture {
                                                    Task {
                                                        await manager.revealTrackInMusicApp(name: selected.name, artist: selected.artist)
                                                    }
                                                }
                                                .help("Click to play in macOS Music")
                                            
                                            Text(selected.artist)
                                                .font(.caption)
                                                .foregroundColor(isDetailArtistHovered ? .purple : .secondary)
                                                .lineLimit(1)
                                                .onHover { isDetailArtistHovered = $0 }
                                                .onTapGesture {
                                                    Task {
                                                        await manager.filterArtistInMusicApp(artist: selected.artist)
                                                    }
                                                }
                                                .help("Click to filter by \(selected.artist) in macOS Music")
                                            
                                            HStack(spacing: 12) {
                                                Text("Plays: \(selected.playCount.formatted())")
                                                Text("Skips: \(selected.skipCount.formatted())")
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
                        HStack(alignment: .top) {
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
                            Spacer()
                            
                            if !manager.forgottenGems.isEmpty {
                                PlaylistActionButton(
                                    title: "Create Playlist",
                                    icon: "music.note.list",
                                    actionName: "Aura - Forgotten Gems",
                                    tracks: manager.forgottenGems,
                                    manager: manager
                                )
                            }
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
                                            TableRowView(track: track, manager: manager)
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
                        HStack(alignment: .top) {
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
                            Spacer()
                            
                            if !manager.loveHateParadox.isEmpty {
                                PlaylistActionButton(
                                    title: "Create Playlist",
                                    icon: "music.note.list",
                                    actionName: "Aura - Love-Hate Paradox",
                                    tracks: manager.loveHateParadox,
                                    manager: manager
                                )
                            }
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
                                            LoveHateRowView(track: track, manager: manager)
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
    @ObservedObject var manager: MusicLibraryManager
    @State private var isHovered = false
    @State private var isGenreHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isHovered ? .purple : .white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .onTapGesture {
                        Task {
                            await manager.filterArtistInMusicApp(artist: track.artist)
                        }
                    }
                    .help("Click to filter by \(track.artist) in macOS Music")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(track.genre)
                .font(.caption)
                .foregroundColor(isGenreHovered ? .purple : .secondary)
                .frame(width: 100, alignment: .leading)
                .onTapGesture {
                    Task {
                        await manager.filterGenreInMusicApp(genre: track.genre)
                    }
                }
                .onHover { isGenreHovered = $0 }
                .help("Click to filter genre '\(track.genre)' in macOS Music")
            
            StarsView(stars: track.ratingStars)
                .frame(width: 80, alignment: .center)
            
            Text(lastPlayedFormatted)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            Task {
                await manager.revealTrackInMusicApp(name: track.name, artist: track.artist)
            }
        }
        .help("Click to reveal track in macOS Music")
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
    @ObservedObject var manager: MusicLibraryManager
    @State private var isHovered = false
    @State private var isGenreHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isHovered ? .purple : .white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .onTapGesture {
                        Task {
                            await manager.filterArtistInMusicApp(artist: track.artist)
                        }
                    }
                    .help("Click to filter by \(track.artist) in macOS Music")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(track.genre)
                .font(.caption)
                .foregroundColor(isGenreHovered ? .purple : .secondary)
                .frame(width: 100, alignment: .leading)
                .onTapGesture {
                    Task {
                        await manager.filterGenreInMusicApp(genre: track.genre)
                    }
                }
                .onHover { isGenreHovered = $0 }
                .help("Click to filter genre '\(track.genre)' in macOS Music")
            
            HStack(spacing: 4) {
                StarsView(stars: track.ratingStars)
                if track.ratingStars == 0 {
                    Text("Plays: \(track.playCount.formatted())")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, alignment: .center)
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.forward.to.line.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 8))
                Text("\(track.skipCount.formatted()) skips")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
            .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            Task {
                await manager.revealTrackInMusicApp(name: track.name, artist: track.artist)
            }
        }
        .help("Click to reveal track in macOS Music")
    }
}

struct PlaylistActionButton: View {
    let title: String
    let icon: String
    let actionName: String
    let tracks: [Track]
    @ObservedObject var manager: MusicLibraryManager
    
    @State private var syncState: SyncState = .idle
    @State private var isHovered = false
    
    enum SyncState {
        case idle, running, success, failure
    }
    
    var body: some View {
        Button(action: {
            guard syncState == .idle else { return }
            syncState = .running
            Task {
                let ok = await manager.createPlaylistInMusicApp(named: actionName, withTracks: tracks)
                withAnimation {
                    syncState = ok ? .success : .failure
                }
                if ok {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation {
                        syncState = .idle
                    }
                }
            }
        }) {
            HStack(spacing: 6) {
                switch syncState {
                case .idle:
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                case .running:
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                    Text("Creating...")
                        .font(.system(size: 10, weight: .bold))
                case .success:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.emerald)
                        .font(.system(size: 10, weight: .bold))
                    Text("Playlist Created!")
                        .foregroundColor(.emerald)
                        .font(.system(size: 10, weight: .bold))
                case .failure:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 10, weight: .bold))
                    Text("Failed")
                        .foregroundColor(.red)
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .disabled(syncState == .running)
    }
}
