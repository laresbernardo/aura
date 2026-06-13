import SwiftUI
import Charts

struct ArtistHallView: View {
    @ObservedObject var manager: MusicLibraryManager
    @State private var showAllArtists = false
    @State private var searchQuery = ""
    @State private var visibleChartArtistsCount = 5
    
    enum ComparisonMetric: String, CaseIterable, Identifiable {
        case time = "Listening Time"
        case counter = "Play Count"
        
        var id: Self { self }
    }
    
    @State private var comparisonMetric: ComparisonMetric = .time
    
    var filteredArtists: [ArtistStat] {
        if searchQuery.isEmpty {
            return manager.topArtistsDetailed
        } else {
            return manager.topArtistsDetailed.filter {
                $0.artist.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Artist Hall of Fame")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("A deep dive into your most-listened artists, analyzing track volumes, play rates, and loyalty engagement scores.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if manager.tracks.isEmpty {
                    GlassCard {
                        HStack {
                            Spacer()
                            Text(manager.allTracks.isEmpty ? "Sync your library to see your Artist Hall of Fame." : "No artists found for the selected Time Range.")
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                        .frame(height: 200)
                    }
                } else {
                    // Search Bar
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.purple)
                                .font(.system(size: 16, weight: .bold))
                            
                            TextField("Search for any artist...", text: $searchQuery)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .font(.system(.body, design: .rounded))
                            
                            if !searchQuery.isEmpty {
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        searchQuery = ""
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        if !searchQuery.isEmpty {
                            Text("\(filteredArtists.count) found")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.purple.opacity(0.15))
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searchQuery)
                    
                    if filteredArtists.isEmpty {
                        // Empty Search State
                        GlassCard {
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "music.mic.slash")
                                    .font(.system(size: 42))
                                    .foregroundColor(.purple.opacity(0.6))
                                Text("No Artists Found")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("We couldn't find any artists matching \"\(searchQuery)\" in your library.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                Spacer()
                            }
                            .frame(height: 220)
                        }
                        .transition(.opacity)
                    } else {
                        let chartArtists = Array(filteredArtists.prefix(visibleChartArtistsCount))
                        let displayedArtists = searchQuery.isEmpty
                            ? (showAllArtists ? Array(filteredArtists.prefix(12)) : Array(filteredArtists.prefix(4)))
                            : filteredArtists
                        
                        // MARK: - Playback Volume Comparison Chart
                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "music.mic")
                                                .foregroundColor(.purple)
                                            Text(searchQuery.isEmpty ? "Playback Volume Comparison" : "Playback Volume: Matches")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }
                                        Text(comparisonMetric == .time 
                                             ? (searchQuery.isEmpty ? "Total listening time across your top artists" : "Total listening time for matches")
                                             : (searchQuery.isEmpty ? "Total play counts across your top artists" : "Total play counts for matches"))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Picker("", selection: $comparisonMetric) {
                                        ForEach(ComparisonMetric.allCases) { metric in
                                            Text(metric.rawValue).tag(metric)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 200)
                                }
                                
                                ScrollView(.vertical, showsIndicators: true) {
                                    Chart(chartArtists) { stat in
                                        BarMark(
                                            x: .value(
                                                comparisonMetric == .time ? "Hours" : "Plays",
                                                comparisonMetric == .time ? (Double(stat.totalPlays) * 210.0 / 3600.0) : Double(stat.totalPlays)
                                            ),
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
                                            Text(comparisonMetric == .time ? stat.totalListeningTimeFormatted : "\(stat.totalPlays.formatted()) plays")
                                                .font(.system(.caption2, design: .monospaced))
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white.opacity(0.85))
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks { value in
                                            AxisValueLabel()
                                                .foregroundStyle(.white.opacity(0.85))
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                                    .frame(height: max(100, CGFloat(chartArtists.count) * 45.0))
                                    .padding(.trailing, 16)
                                }
                                .frame(height: max(100, min(350, CGFloat(chartArtists.count) * 45.0)))
                                .padding(.vertical, 10)
                                
                                // Chart Pagination Controls
                                if filteredArtists.count > 5 {
                                    Divider().background(Color.white.opacity(0.06))
                                    
                                    HStack(spacing: 16) {
                                        if visibleChartArtistsCount > 5 {
                                            Button(action: {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                    visibleChartArtistsCount = max(5, visibleChartArtistsCount - 5)
                                                }
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "minus.circle")
                                                    Text("Show Less")
                                                }
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(.semibold)
                                                .foregroundColor(.purple)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(Capsule().fill(Color.white.opacity(0.05)))
                                                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        if visibleChartArtistsCount < filteredArtists.count {
                                            Button(action: {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                    visibleChartArtistsCount = min(filteredArtists.count, visibleChartArtistsCount + 5)
                                                }
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "plus.circle")
                                                    Text("Show More (+5)")
                                                }
                                                .font(.system(.subheadline, design: .rounded))
                                                .fontWeight(.semibold)
                                                .foregroundColor(.purple)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(Capsule().fill(Color.white.opacity(0.05)))
                                                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("Showing \(chartArtists.count) of \(filteredArtists.count) artists")
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding(24)
                        }
                        .glassCardHoverEffect()
                        
                        // MARK: - Detailed Artist Stat Cards
                        Text(searchQuery.isEmpty ? "Top Artist Profiles" : "Matching Artist Profiles")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.top, 8)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(displayedArtists) { stat in
                                ArtistProfileCard(stat: stat, manager: manager)
                            }
                        }
                        
                        if searchQuery.isEmpty && manager.topArtistsDetailed.count > 4 {
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                        showAllArtists.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Text(showAllArtists ? "Show Less" : "Show More Artists")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Image(systemName: showAllArtists ? "chevron.up" : "chevron.down")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.top, 10)
                        }
                    }
                }
            }
            .padding(4)
        }
        .onChange(of: searchQuery) { newValue in
            visibleChartArtistsCount = 5
        }
    }
}

struct ArtistProfileCard: View {
    let stat: ArtistStat
    @ObservedObject var manager: MusicLibraryManager
    @State private var isHovered = false
    @State private var hoveredTrackId: UUID? = nil
    
    var body: some View {
        GlassCard(cornerRadius: 16, shadowRadius: 10) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stat.artist)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(stat.trackCount.formatted()) tracks in library")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple.opacity(0.2), .pink.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.purple)
                    }
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                // Stat Rows
                VStack(spacing: 12) {
                    HStack {
                        Text("Time Listened")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(stat.totalListeningTimeFormatted)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Total Plays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(stat.totalPlays.formatted())
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Average plays / song")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f", stat.averagePlaysPerTrack))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Total Skips")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(stat.totalSkips.formatted())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Engagement Score")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f%%", stat.engagementScore))
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(stat.engagementScore > 75 ? .emerald : stat.engagementScore > 40 ? .orange : .red)
                    }
                }
                
                // Engagement Indicator Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(stat.engagementScore / 100.0), height: 6)
                            .shadow(color: .purple.opacity(0.4), radius: 3)
                    }
                }
                .frame(height: 6)
                .padding(.top, 4)
                
                // Detailed Songs Sub-section
                let artistTracks = manager.tracks
                    .filter { track in
                        ArtistResolver.resolve(track.artist)
                            .contains(where: { resolvedArtist in
                                resolvedArtist.localizedCaseInsensitiveCompare(stat.artist) == .orderedSame
                            })
                    }
                    .sorted(by: { $0.playCount > $1.playCount })
                
                if !artistTracks.isEmpty {
                    Divider().background(Color.white.opacity(0.06))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Top Tracks (Click to Play)")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .padding(.bottom, 2)
                        
                        let displayTracks = Array(artistTracks.prefix(3))
                        let maxPlays = displayTracks.first?.playCount ?? 1
                        
                        ForEach(Array(displayTracks.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 8) {
                                // Rank
                                Text("#\(index + 1)")
                                    .font(.system(.caption2, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple.opacity(0.8))
                                    .frame(width: 18, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    // Clickable Title
                                    Button(action: {
                                        Task {
                                            await manager.revealTrackInMusicApp(name: track.name, artist: track.artist)
                                        }
                                    }) {
                                        Text(track.name)
                                            .font(.system(.caption, design: .rounded))
                                            .fontWeight(.semibold)
                                            .foregroundColor(hoveredTrackId == track.id ? .purple : .white)
                                            .lineLimit(1)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { isHovering in
                                        hoveredTrackId = isHovering ? track.id : nil
                                    }
                                    
                                    // Mini Ranked Progress Bar
                                    GeometryReader { barGeo in
                                        let ratio = CGFloat(track.playCount) / CGFloat(max(1, maxPlays))
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.white.opacity(0.04))
                                                .frame(height: 4)
                                            Capsule()
                                                .fill(LinearGradient(colors: [.purple.opacity(0.7), .pink.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: barGeo.size.width * ratio, height: 4)
                                        }
                                    }
                                    .frame(height: 4)
                                }
                                
                                Spacer(minLength: 8)
                                
                                // Plays / Time info
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(track.playCount) plays")
                                        .font(.system(.caption2, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    // Est. duration
                                    let mins = Int(Double(track.playCount) * 210.0 / 60.0)
                                    Text("\(mins)m")
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(20)
        }
        .glassCardHoverEffect(cornerRadius: 16)
        .onHover { isHovered = $0 }
        .onTapGesture {
            Task {
                await manager.filterArtistInMusicApp(artist: stat.artist)
            }
        }
        .help("Click card to view artist in macOS Music, or track title to play")
    }
}
