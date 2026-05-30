import SwiftUI
import Charts

struct ArtistHallView: View {
    @ObservedObject var manager: MusicLibraryManager
    @State private var showAllArtists = false
    
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
                
                if manager.topArtistsDetailed.isEmpty {
                    GlassCard {
                        HStack {
                            Spacer()
                            Text("Sync your library to see your Artist Hall of Fame.")
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                        .frame(height: 200)
                    }
                } else {
                    let top5 = Array(manager.topArtistsDetailed.prefix(5))
                    let displayedArtists = showAllArtists ? Array(manager.topArtistsDetailed.prefix(12)) : Array(manager.topArtistsDetailed.prefix(4))
                    
                    // MARK: - Playback Volume Comparison Chart
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "music.mic")
                                        .foregroundColor(.purple)
                                    Text("Playback Volume Comparison")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                Text("Total play counts across your top artists")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Chart(top5) { stat in
                                BarMark(
                                    x: .value("Plays", stat.totalPlays),
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
                                    Text("\(stat.totalPlays) plays")
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
                            .frame(height: 220)
                            .padding(.vertical, 10)
                        }
                        .padding(24)
                    }
                    .glassCardHoverEffect()
                    
                    // MARK: - Detailed Artist Stat Cards
                    Text("Top Artist Profiles")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(displayedArtists) { stat in
                            ArtistProfileCard(stat: stat, manager: manager)
                        }
                    }
                    
                    if manager.topArtistsDetailed.count > 4 {
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
            .padding(4)
        }
    }
}

struct ArtistProfileCard: View {
    let stat: ArtistStat
    @ObservedObject var manager: MusicLibraryManager
    @State private var isHovered = false
    
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
                        
                        Text("\(stat.trackCount) tracks in library")
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
                        Text("Total Plays")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(stat.totalPlays)")
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
                        Text("\(stat.totalSkips)")
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
        .help("Click to filter \(stat.artist) in macOS Music")
    }
}
