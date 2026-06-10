import SwiftUI
import Charts

struct PhotosBehaviorView: View {
    @ObservedObject var manager: PhotosLibraryManager
    
    @State private var selectedGranularity: CaptureGranularity = .hour
    @State private var hoveredKey: Int? = nil
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
                    // KPI 1: Peak Shooting Day
                    PhotosMetricCard(
                        title: "Peak Shooting Day",
                        value: manager.peakWeekday,
                        subtitle: String(format: "%.1f%% of library captures", manager.peakWeekdayPercentage),
                        icon: "calendar.badge.clock",
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
                
                // MARK: - Capture Time Distribution
                GlassCard {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "chart.histogram.fill")
                                        .foregroundColor(.emerald)
                                    Text("Capture Time Distribution")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                Text(granularityDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Picker("", selection: $selectedGranularity) {
                                ForEach(CaptureGranularity.allCases) { gran in
                                    Text(gran.rawValue).tag(gran)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 340)
                        }
                        
                        if activeHistogramData.isEmpty {
                            Text("No time metrics found.")
                                .foregroundColor(.secondary)
                                .frame(height: 200)
                        } else {
                            Chart {
                                ForEach(activeHistogramData) { dataPoint in
                                    BarMark(
                                        x: .value(selectedGranularity.rawValue, dataPoint.intKey),
                                        y: .value("Captures", dataPoint.count)
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
                                        if hoveredKey == dataPoint.intKey && dataPoint.count > 0 {
                                            Text(dataPoint.count.formatted())
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
                                                if let key: Int = proxy.value(atX: location.x) {
                                                    hoveredKey = key
                                                } else {
                                                    hoveredKey = nil
                                                }
                                            case .ended:
                                                hoveredKey = nil
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
                                AxisMarks(values: xAxisValues) { value in
                                    if let key = value.as(Int.self) {
                                        AxisValueLabel(xAxisLabel(for: key))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .font(.system(size: 9, design: .rounded))
                                    }
                                }
                            }
                            .chartXScale(domain: xScaleDomain)
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
    
    enum CaptureGranularity: String, CaseIterable, Identifiable {
        case hour = "Hour of Day"
        case weekday = "Day of Week"
        case dayOfMonth = "Day of Month"
        case month = "Month"
        
        var id: String { rawValue }
    }
    
    private var activeHistogramData: [HistogramDataPoint] {
        switch selectedGranularity {
        case .hour:
            return manager.hourlyHistogramData
        case .weekday:
            return manager.weekdayHistogramData
        case .dayOfMonth:
            return manager.dayOfMonthHistogramData
        case .month:
            return manager.monthHistogramData
        }
    }
    
    private var granularityDescription: String {
        switch selectedGranularity {
        case .hour:
            return "Total counts grouped by hourly capture blocks across a 24-hour cycle"
        case .weekday:
            return "Total counts grouped by day of the week (Monday through Sunday)"
        case .dayOfMonth:
            return "Total counts grouped by day of the month (1st through 31st)"
        case .month:
            return "Total counts grouped by calendar month (January through December)"
        }
    }
    
    private var xAxisValues: [Int] {
        switch selectedGranularity {
        case .hour:
            return [0, 3, 6, 9, 12, 15, 18, 21, 23]
        case .weekday:
            return Array(1...7)
        case .dayOfMonth:
            return [1, 5, 10, 15, 20, 25, 30, 31]
        case .month:
            return Array(1...12)
        }
    }
    
    private var xScaleDomain: ClosedRange<Int> {
        switch selectedGranularity {
        case .hour:
            return 0...23
        case .weekday:
            return 1...7
        case .dayOfMonth:
            return 1...31
        case .month:
            return 1...12
        }
    }
    
    private func xAxisLabel(for key: Int) -> String {
        switch selectedGranularity {
        case .hour:
            switch key {
            case 0: return "12 AM"
            case 12: return "12 PM"
            default:
                let suffix = key >= 12 ? "PM" : "AM"
                let val = key > 12 ? key - 12 : key
                return "\(val) \(suffix)"
            }
        case .weekday:
            let formatter = DateFormatter()
            let symbols = formatter.shortWeekdaySymbols ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            guard key >= 1 && key <= 7 else { return "" }
            return symbols[key - 1]
        case .dayOfMonth:
            return "\(key)"
        case .month:
            let formatter = DateFormatter()
            let symbols = formatter.shortMonthSymbols ?? ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            guard key >= 1 && key <= 12 else { return "" }
            return symbols[key - 1]
        }
    }
    
    private var primaryCameraName: String {
        return manager.cameraDistribution.first?.camera ?? "Unknown Device"
    }
    
    private var favoriteCropCategory: String {
        return manager.aspectRatios.first?.category ?? "Unknown Crop"
    }
}
