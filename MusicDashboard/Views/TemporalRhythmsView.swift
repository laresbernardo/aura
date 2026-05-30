import SwiftUI
import Charts

struct TemporalRhythmsView: View {
    @ObservedObject var manager: MusicLibraryManager
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Temporal Sonic Rhythms")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Analyze the exact hours you listen to music, mapping your auditory behavior into a daily clock cycle.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if manager.listeningHourCounts.isEmpty {
                    GlassCard {
                        HStack {
                            Spacer()
                            Text("Sync your library to see your Temporal Sonic Rhythms.")
                                .foregroundColor(.secondary)
                                .padding()
                            Spacer()
                        }
                        .frame(height: 200)
                    }
                } else {
                    // MARK: - Listening Activity Hourly Chart
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.purple)
                                    Text("Hourly Playback Distribution")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                Text("Cumulative playback counts across 24 hourly blocks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Chart {
                                ForEach(0..<24, id: \.self) { hour in
                                    let count = manager.listeningHourCounts[hour] ?? 0
                                    BarMark(
                                        x: .value("Hour", hour),
                                        y: .value("Plays", count)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.85), .indigo.opacity(0.4)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(4)
                                }
                            }
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                    AxisValueLabel()
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21, 23]) { value in
                                    if let hour = value.as(Int.self) {
                                        AxisValueLabel(hourLabel(hour))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .font(.system(size: 9, design: .rounded))
                                    }
                                }
                            }
                            .frame(height: 220)
                            .padding(.vertical, 10)
                        }
                        .padding(24)
                    }
                    .glassCardHoverEffect()
                    
                    // MARK: - Smart Temporal Recommendation
                    currentVibeCard
                }
            }
            .padding(4)
        }
    }
    
    // Label hour integer to AM/PM string (e.g. 0 -> 12 AM, 12 -> 12 PM)
    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12 AM"
        case 12: return "12 PM"
        default:
            let suffix = hour >= 12 ? "PM" : "AM"
            let val = hour > 12 ? hour - 12 : hour
            return "\(val) \(suffix)"
        }
    }
    
    // Dynamic vibe recommendation based on current system time
    @ViewBuilder
    private var currentVibeCard: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let recommendation = vibeRecommendation(for: hour)
        
        GlassCard(cornerRadius: 18, shadowRadius: 12) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CURRENT SYSTEM TIME REC")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white.opacity(0.55))
                        
                        HStack(spacing: 8) {
                            Image(systemName: recommendation.icon)
                                .foregroundColor(recommendation.color)
                                .font(.headline)
                            Text(recommendation.title)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                    
                    Text(String(format: "%02d:00", hour))
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(recommendation.color.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .foregroundColor(recommendation.color)
                            .font(.title3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested Music Mode:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(recommendation.advice)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(24)
        }
        .glassCardHoverEffect(cornerRadius: 18)
    }
    
    // Vibe detail generator
    private func vibeRecommendation(for hour: Int) -> (title: String, icon: String, advice: String, color: Color) {
        if hour >= 6 && hour < 12 {
            return (
                title: "Morning Caffeine Boost",
                icon: "sunrise.fill",
                advice: "Acoustic Folk, Jazz, and Upbeat Indie Pop to start your day with fresh energy.",
                color: .orange
            )
        } else if hour >= 12 && hour < 18 {
            return (
                title: "Afternoon Workday Focus",
                icon: "sun.max.fill",
                advice: "Lofi Beats, deep Synthwave, and Classical to maintain focus and high productivity.",
                color: .emerald
            )
        } else if hour >= 18 && hour < 24 {
            return (
                title: "Sunset Wind Down",
                icon: "sunset.fill",
                advice: "Dreamy Synthpop, smooth R&B, and chill Indie Rock to transition into post-work relaxation.",
                color: .pink
            )
        } else {
            return (
                title: "Midnight Owl Ambient",
                icon: "moon.stars.fill",
                advice: "Atmospheric Drone, Ambient soundscapes, and down-tempo IDM for deep concentration or sleep.",
                color: .indigo
            )
        }
    }
}
