import SwiftUI
import Charts

struct TimeMachineView: View {
    @ObservedObject var manager: MusicLibraryManager
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header Section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time Machine")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Explore your library's growth over time and the historical eras of your music collection.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Tracks Added Timeline (Library Growth)
                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.purple)
                                Text("Library Growth Timeline")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text("Cumulative history of songs added by month and year")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if manager.cumulativeTracksAddedTimeline.isEmpty {
                            HStack {
                                Spacer()
                                Text("No timeline data available. Add tracks or toggle Demo Mode.")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                            .frame(height: 240)
                        } else {
                            VStack {
                                Chart(manager.cumulativeTracksAddedTimeline) { stat in
                                    // Area fill for glowing background effect
                                    AreaMark(
                                        x: .value("Date", stat.date),
                                        y: .value("Tracks Added", stat.count)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.purple.opacity(0.35), Color.purple.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.cardinal)
                                    
                                    // Sharp top border line
                                    LineMark(
                                        x: .value("Date", stat.date),
                                        y: .value("Tracks Added", stat.count)
                                    )
                                    .foregroundStyle(Color.purple)
                                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                                    .interpolationMethod(.cardinal)
                                }
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .month, count: 6)) { value in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                        AxisValueLabel(format: .dateTime.year().month())
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 9, design: .monospaced))
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                        AxisValueLabel()
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 9, design: .monospaced))
                                    }
                                }
                                .frame(height: 240)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .padding(24)
                }
                .glassCardHoverEffect()
                
                // MARK: - Era Breakdown
                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.cyan)
                                Text("Era Breakdown")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text("Distribution of tracks based on release year (decade)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if manager.eraDistribution.isEmpty {
                            HStack {
                                Spacer()
                                Text("No release year details found in library tracks.")
                                    .foregroundColor(.secondary)
                                    .padding()
                                Spacer()
                            }
                            .frame(height: 240)
                        } else {
                            VStack {
                                Chart(manager.eraDistribution) { stat in
                                    BarMark(
                                        x: .value("Era", stat.era),
                                        y: .value("Count", stat.count)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.cyan.opacity(0.9), Color.cyan.opacity(0.35)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(6)
                                    .annotation(position: .top) {
                                        Text("\(stat.count)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white.opacity(0.85))
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks { value in
                                        AxisValueLabel()
                                            .foregroundStyle(.white.opacity(0.9))
                                            .font(.caption)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.05))
                                        AxisValueLabel()
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 9, design: .monospaced))
                                    }
                                }
                                .frame(height: 240)
                                .padding(.vertical, 10)
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
}
