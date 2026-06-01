import SwiftUI
import Charts

struct PhotosBehaviorView: View {
    @ObservedObject var manager: PhotosLibraryManager
    
    @State private var hoveredHour: Int? = nil
    @State private var hoveredCamera: String? = nil
    @State private var hoveredCrop: String? = nil
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Capture Behavior")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Detailed distributions of your shooting clock, camera devices, and crop layouts.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - Behavioral KPIs
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    // KPI 1: Golden Hour Focus
                    PhotosMetricCard(
                        title: "Golden Hour Snaps",
                        value: "\(goldenHourCount.formatted()) Captures",
                        subtitle: String(format: "%.1f%% of library taken at sunset", goldenHourPercentage),
                        icon: "sunset.fill",
                        gradient: LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // KPI 2: Preferred Device
                    PhotosMetricCard(
                        title: "Primary Camera",
                        value: primaryCameraName,
                        subtitle: "Most active shooting tool",
                        icon: "camera.fill",
                        gradient: LinearGradient(colors: [.emerald, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    
                    // KPI 3: Preferred Crop Category
                    PhotosMetricCard(
                        title: "Favorite Format",
                        value: favoriteCropCategory,
                        subtitle: "Most popular crop layout",
                        icon: "crop.rotate",
                        gradient: LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                }
                
                // MARK: - Hourly Capture Rhythms
                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.emerald)
                                Text("Hourly Capture Distribution")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            Text("Total counts grouped by hourly capture blocks across a 24-hour cycle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if manager.captureHourCounts.isEmpty {
                            Text("No time metrics found.")
                                .foregroundColor(.secondary)
                                .frame(height: 200)
                        } else {
                            Chart {
                                ForEach(0..<24, id: \.self) { hour in
                                    let count = manager.captureHourCounts[hour] ?? 0
                                    BarMark(
                                        x: .value("Hour", hour),
                                        y: .value("Captures", count)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.emerald.opacity(0.85), .teal.opacity(0.35)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .cornerRadius(4)
                                    .annotation(position: .top) {
                                        if hoveredHour == hour && count > 0 {
                                            Text(count.formatted())
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.emerald.opacity(0.85))
                                                .cornerRadius(4)
                                                .offset(y: -4)
                                        }
                                    }
                                }
                            }
                            .chartOverlay { proxy in
                                GeometryReader { geo in
                                    Rectangle()
                                        .fill(Color.clear)
                                        .contentShape(Rectangle())
                                        .onContinuousHover { phase in
                                            switch phase {
                                            case .active(let location):
                                                if let hour: Int = proxy.value(atX: location.x) {
                                                    hoveredHour = hour
                                                } else {
                                                    hoveredHour = nil
                                                }
                                            case .ended:
                                                hoveredHour = nil
                                            }
                                        }
                                }
                            }
                            .chartYAxis {
                                AxisMarks { value in
                                    AxisGridLine().foregroundStyle(Color.white.opacity(0.04))
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
                            .frame(height: 200)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(24)
                }
                .glassCardHoverEffect()
                
                // MARK: - Row of Gear & Aspect Ratios
                HStack(spacing: 24) {
                    // Camera Gear Distribution Chart
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Camera Gear")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Distribution of captures by device body")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if manager.cameraDistribution.isEmpty {
                                Text("No camera gear detected.")
                                    .foregroundColor(.secondary)
                                    .frame(height: 180)
                            } else {
                                Chart(manager.cameraDistribution) { stat in
                                    BarMark(
                                        x: .value("Captures", stat.count),
                                        y: .value("Camera", stat.camera)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.cyan.opacity(0.85), .blue.opacity(0.35)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(4)
                                    .annotation(position: .trailing) {
                                        if hoveredCamera == stat.camera {
                                            Text("\(stat.count.formatted()) photos")
                                                .font(.system(.caption2, design: .monospaced))
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.cyan.opacity(0.85))
                                                .cornerRadius(4)
                                        } else {
                                            Text(stat.count.formatted())
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                }
                                .chartOverlay { proxy in
                                    GeometryReader { geo in
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                            .onContinuousHover { phase in
                                                switch phase {
                                                case .active(let location):
                                                    if let camera: String = proxy.value(atY: location.y) {
                                                        hoveredCamera = camera
                                                    } else {
                                                        hoveredCamera = nil
                                                    }
                                                case .ended:
                                                    hoveredCamera = nil
                                                }
                                            }
                                    }
                                }
                                .chartXAxis(.hidden)
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel()
                                            .foregroundStyle(.white.opacity(0.85))
                                            .font(.system(size: 10))
                                    }
                                }
                                .frame(height: 180)
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(24)
                    }
                    .glassCardHoverEffect()
                    
                    // Aspect Ratio Composition Chart
                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Crop Composition")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Aspect ratio distribution of crop shapes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if manager.aspectRatios.isEmpty {
                                Text("No aspect categories identified.")
                                    .foregroundColor(.secondary)
                                    .frame(height: 180)
                            } else {
                                Chart(manager.aspectRatios) { stat in
                                    BarMark(
                                        x: .value("Percentage", stat.percentage),
                                        y: .value("Aspect", stat.category)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.85), .indigo.opacity(0.35)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(4)
                                    .annotation(position: .trailing) {
                                        if hoveredCrop == stat.category {
                                            Text("\(stat.count.formatted()) photos")
                                                .font(.system(.caption2, design: .monospaced))
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.purple.opacity(0.85))
                                                .cornerRadius(4)
                                        } else {
                                            Text(String(format: "%.1f%%", stat.percentage))
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                }
                                .chartOverlay { proxy in
                                    GeometryReader { geo in
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                            .onContinuousHover { phase in
                                                switch phase {
                                                case .active(let location):
                                                    if let crop: String = proxy.value(atY: location.y) {
                                                        hoveredCrop = crop
                                                    } else {
                                                        hoveredCrop = nil
                                                    }
                                                case .ended:
                                                    hoveredCrop = nil
                                                }
                                            }
                                    }
                                }
                                .chartXAxis(.hidden)
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisValueLabel()
                                            .foregroundStyle(.white.opacity(0.85))
                                            .font(.system(size: 10))
                                    }
                                }
                                .frame(height: 180)
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
    
    // MARK: - Auxiliary Computations & Helpers
    
    private var goldenHourCount: Int {
        return manager.photos.filter { item in
            let hour = Calendar.current.component(.hour, from: item.capturedDate)
            return hour >= 17 && hour < 20 // 5 PM - 8 PM Sunset/Golden glow
        }.count
    }
    
    private var goldenHourPercentage: Double {
        guard manager.totalAssetsCount > 0 else { return 0.0 }
        return (Double(goldenHourCount) / Double(manager.totalAssetsCount)) * 100.0
    }
    
    private var primaryCameraName: String {
        return manager.cameraDistribution.first?.camera ?? "Unknown Device"
    }
    
    private var favoriteCropCategory: String {
        return manager.aspectRatios.first?.category ?? "Unknown Crop"
    }
    
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
}
