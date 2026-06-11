import SwiftUI
import MapKit
import AppKit

// MARK: - Pass Through View for Mouse Events
class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

// MARK: - Heatmap Overlay Renderer for Blended Density Areas
class HeatmapOverlayRenderer: MKOverlayRenderer {
    let count: Int
    let maxCount: Int
    
    init(circle: MKCircle, count: Int, maxCount: Int) {
        self.count = count
        self.maxCount = maxCount
        super.init(overlay: circle)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let rect = self.rect(for: self.overlay.boundingMapRect)
        
        context.saveGState()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Logarithmic scaling for relative density
        let ratio: Double
        if maxCount <= 5 {
            ratio = maxCount > 1 ? Double(count) / Double(maxCount) : 1.0
        } else {
            ratio = count > 1 ? log2(Double(count)) / log2(Double(maxCount)) : (count > 0 ? 0.05 : 0.0)
        }
        
        // Dynamic relative blending heatmap gradient based on active maxCount density
        let colors: [CGColor]
        if maxCount <= 5 {
            // Absolute fallbacks for very low counts (to avoid making 1 photo show as intense red)
            if count <= 1 {
                colors = [
                    NSColor.systemTeal.withAlphaComponent(0.45).cgColor,
                    NSColor.systemTeal.withAlphaComponent(0.18).cgColor,
                    NSColor.systemTeal.withAlphaComponent(0.0).cgColor
                ]
            } else if count <= 3 {
                colors = [
                    NSColor.systemOrange.withAlphaComponent(0.55).cgColor,
                    NSColor.systemOrange.withAlphaComponent(0.30).cgColor,
                    NSColor.systemYellow.withAlphaComponent(0.12).cgColor,
                    NSColor.systemYellow.withAlphaComponent(0.0).cgColor
                ]
            } else {
                colors = [
                    NSColor.systemRed.withAlphaComponent(0.65).cgColor,
                    NSColor.systemRed.withAlphaComponent(0.50).cgColor,
                    NSColor.systemOrange.withAlphaComponent(0.35).cgColor,
                    NSColor.systemYellow.withAlphaComponent(0.15).cgColor,
                    NSColor.systemYellow.withAlphaComponent(0.0).cgColor
                ]
            }
        } else {
            // Relative dynamic scaling
            if ratio >= 0.65 {
                // High relative density: Intense Red core
                colors = [
                    NSColor.systemRed.withAlphaComponent(0.65).cgColor,
                    NSColor.systemRed.withAlphaComponent(0.50).cgColor,
                    NSColor.systemOrange.withAlphaComponent(0.35).cgColor,
                    NSColor.systemYellow.withAlphaComponent(0.15).cgColor,
                    NSColor.systemYellow.withAlphaComponent(0.0).cgColor
                ]
            } else if ratio >= 0.20 {
                // Medium relative density: Orange-Yellow glow
                colors = [
                    NSColor.systemOrange.withAlphaComponent(0.55).cgColor,
                    NSColor.systemOrange.withAlphaComponent(0.30).cgColor,
                    NSColor.systemYellow.withAlphaComponent(0.12).cgColor,
                    NSColor.systemYellow.withAlphaComponent(0.0).cgColor
                ]
            } else {
                // Low relative density: Crisp Teal glow
                colors = [
                    NSColor.systemTeal.withAlphaComponent(0.45).cgColor,
                    NSColor.systemTeal.withAlphaComponent(0.18).cgColor,
                    NSColor.systemTeal.withAlphaComponent(0.0).cgColor
                ]
            }
        }
        
        let locations: [CGFloat] = colors.count == 3 ? [0.0, 0.5, 1.0] : (colors.count == 4 ? [0.0, 0.35, 0.70, 1.0] : [0.0, 0.18, 0.45, 0.75, 1.0])
        
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
            context.restoreGState()
            return
        }
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2.0
        
        context.addEllipse(in: rect)
        context.clip()
        
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0.0,
            endCenter: center,
            endRadius: radius,
            options: .drawsAfterEndLocation
        )
        
        context.restoreGState()
    }
}


// MARK: - Heatmap Circle Subclass for Custom Rendering Data
class HeatmapCircle: MKCircle {
    var clusterCount: Int = 1
}

// MARK: - Native MKMapView Wrapper with Pulsing Heatmap Circles
struct HeatmapMapView: NSViewRepresentable {
    let clusters: [MappedCluster]
    @Binding var selectedCluster: MappedCluster?
    @Binding var mapType: MKMapType
    @Binding var centerTrigger: MKCoordinateRegion?
    @Binding var currentRegion: MKCoordinateRegion
    let visualizationMode: PhotosHeatmapView.VisualizationMode
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsZoomControls = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.mapType = mapType
        mapView.setRegion(currentRegion, animated: false)
        return mapView
    }
    
    func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.parent = self
        nsView.mapType = mapType
        
        // Calculate viewport-relative maxCount
        let visibleMapRect = nsView.visibleMapRect
        let visibleClusters = clusters.filter { cluster in
            visibleMapRect.contains(MKMapPoint(cluster.coordinate))
        }
        let maxCount = visibleClusters.map { $0.count }.max() ?? 1
        
        if context.coordinator.lastMaxCount != maxCount {
            context.coordinator.lastMaxCount = maxCount
            // Force redraw of overlays and annotations with new relative scale
            nsView.removeOverlays(nsView.overlays)
            nsView.removeAnnotations(nsView.annotations)
        }
        
        // 1. Sync Annotations
        let existingAnnotations = nsView.annotations.compactMap { $0 as? PhotoClusterAnnotation }
        let newAnnotations = clusters.map { cluster in
            PhotoClusterAnnotation(
                coordinate: cluster.coordinate,
                title: cluster.cityName,
                subtitle: "\(cluster.count) captures",
                cluster: cluster
            )
        }
        
        let existingKeys = Set(existingAnnotations.map { $0.cluster.id })
        let newKeys = Set(newAnnotations.map { $0.cluster.id })
        
        // Re-draw annotations only if clusters changed or count in clusters changed
        if existingKeys != newKeys || existingAnnotations.map({ $0.cluster.count }) != newAnnotations.map({ $0.cluster.count }) {
            nsView.removeAnnotations(nsView.annotations)
            nsView.addAnnotations(newAnnotations)
        }
        
        // 1b. Sync Overlays (Heatmap mode only)
        if visualizationMode == .heatmap {
            let delta = nsView.region.span.latitudeDelta
            let baseRadius: Double
            if delta > 40.0 {
                baseRadius = 300_000
            } else if delta > 8.0 {
                baseRadius = 100_000
            } else if delta > 2.0 {
                baseRadius = 25_000
            } else if delta > 0.4 {
                baseRadius = 4_000
            } else if delta > 0.08 {
                baseRadius = 500
            } else {
                baseRadius = 70
            }
            
            let existingCircles = nsView.overlays.compactMap { $0 as? HeatmapCircle }
            let existingCircleKeys = Set(existingCircles.map { "\($0.coordinate.latitude),\($0.coordinate.longitude),\($0.clusterCount)" })
            let newCircleKeys = Set(clusters.map { "\($0.coordinate.latitude),\($0.coordinate.longitude),\($0.count)" })
            
            let existingBaseRadius = context.coordinator.lastBaseRadius
            if existingCircleKeys != newCircleKeys || abs(existingBaseRadius - baseRadius) > 1.0 {
                context.coordinator.lastBaseRadius = baseRadius
                let newOverlays = clusters.map { cluster -> HeatmapCircle in
                    let scale = 0.5 + log2(Double(cluster.count)) * 0.15
                    let scaledRadius = baseRadius * scale
                    let circle = HeatmapCircle(center: cluster.coordinate, radius: scaledRadius)
                    circle.clusterCount = cluster.count
                    return circle
                }
                nsView.removeOverlays(nsView.overlays)
                nsView.addOverlays(newOverlays)
            }
        } else {
            if !nsView.overlays.isEmpty {
                nsView.removeOverlays(nsView.overlays)
            }
        }
        
        // 2. Center/Zoom Trigger
        if let targetRegion = centerTrigger {
            nsView.setRegion(targetRegion, animated: true)
            DispatchQueue.main.async {
                self.centerTrigger = nil
            }
        }
        
        // 3. Selection Sync
        if let selected = selectedCluster {
            if let matchingAnnotation = nsView.annotations.compactMap({ $0 as? PhotoClusterAnnotation }).first(where: { $0.cluster.id == selected.id }) {
                if !nsView.selectedAnnotations.contains(where: { ($0 as? PhotoClusterAnnotation)?.cluster.id == selected.id }) {
                    nsView.selectAnnotation(matchingAnnotation, animated: true)
                }
            }
        } else {
            for annotation in nsView.selectedAnnotations {
                nsView.deselectAnnotation(annotation, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: HeatmapMapView
        var lastMaxCount: Int = 1
        var lastBaseRadius: Double = 0.0
        
        init(_ parent: HeatmapMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let clusterAnnotation = annotation as? PhotoClusterAnnotation else { return nil }
            
            let identifier = "HeatmapPulseView"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: clusterAnnotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = clusterAnnotation
            }
            
            let count = clusterAnnotation.cluster.count
            let isSelected = (clusterAnnotation.cluster.id == parent.selectedCluster?.id)
            let isHeatmapMode = (parent.visualizationMode == .heatmap)
            
            // Calculate scale sizing
            let baseSize = isHeatmapMode ? CGFloat(10) : CGFloat(max(10, min(30, 6 + log2(Double(count)) * 3.0)))
            let finalSize = isSelected ? (isHeatmapMode ? 16 : baseSize * 1.35 + 4) : baseSize
            
            annotationView?.frame = CGRect(x: 0, y: 0, width: finalSize, height: finalSize)
            
            // Clean up any existing subviews or sublayers
            annotationView?.subviews.forEach { $0.removeFromSuperview() }
            annotationView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            // Setup core background view
            let backingView = PassThroughView(frame: annotationView?.bounds ?? .zero)
            backingView.wantsLayer = true
            
            // Determine density color theme based on relative scale
            let maxCount = self.lastMaxCount
            
            let color: NSColor
            if maxCount <= 5 {
                if count <= 1 {
                    color = NSColor.systemTeal // Low density
                } else if count <= 3 {
                    color = NSColor.systemOrange // Medium density
                } else {
                    color = NSColor.systemRed // High density
                }
            } else {
                let ratio = count > 1 ? log2(Double(count)) / log2(Double(maxCount)) : (count > 0 ? 0.05 : 0.0)
                if ratio >= 0.65 {
                    color = NSColor.systemRed // High relative density
                } else if ratio >= 0.20 {
                    color = NSColor.systemOrange // Medium relative density
                } else {
                    color = NSColor.systemTeal // Low relative density
                }
            }
            
            if isHeatmapMode {
                // In Heatmap mode, draw extremely subtle clickable dots on top of the blended area overlays
                backingView.layer?.backgroundColor = isSelected ? color.withAlphaComponent(0.65).cgColor : color.withAlphaComponent(0.12).cgColor
                backingView.layer?.cornerRadius = finalSize / 2.0
                backingView.layer?.borderColor = isSelected ? NSColor.white.cgColor : color.withAlphaComponent(0.40).cgColor
                backingView.layer?.borderWidth = isSelected ? 1.5 : 0.8
                
                // Solid center white core dot
                let coreDotSize = isSelected ? CGFloat(7) : CGFloat(4.5)
                let coreDot = PassThroughView(frame: CGRect(
                    x: (finalSize - coreDotSize) / 2.0,
                    y: (finalSize - coreDotSize) / 2.0,
                    width: coreDotSize,
                    height: coreDotSize
                ))
                coreDot.wantsLayer = true
                coreDot.layer?.backgroundColor = NSColor.white.cgColor
                coreDot.layer?.cornerRadius = coreDotSize / 2.0
                coreDot.layer?.shadowColor = NSColor.white.cgColor
                coreDot.layer?.shadowRadius = isSelected ? 2.5 : 1.0
                coreDot.layer?.shadowOpacity = 0.8
                coreDot.layer?.shadowOffset = .zero
                
                backingView.addSubview(coreDot)
                annotationView?.addSubview(backingView)
            } else {
                // In Points mode, draw the full rich pulsing markers
                backingView.layer?.backgroundColor = isSelected ? color.withAlphaComponent(0.7).cgColor : color.withAlphaComponent(0.22).cgColor
                backingView.layer?.cornerRadius = finalSize / 2.0
                backingView.layer?.borderColor = isSelected ? NSColor.white.cgColor : color.withAlphaComponent(0.45).cgColor
                backingView.layer?.borderWidth = isSelected ? 1.5 : 0.8
                
                // Glowing shadow effect
                backingView.layer?.shadowColor = (isSelected ? NSColor.white : color).cgColor
                backingView.layer?.shadowRadius = isSelected ? 8 : 3
                backingView.layer?.shadowOpacity = isSelected ? 0.85 : 0.35
                backingView.layer?.shadowOffset = .zero
                
                // Pulsing Ring Animation - only show if selected or larger cluster (count >= 10)
                if isSelected || count >= 10 {
                    let pulseLayer = CALayer()
                    pulseLayer.frame = backingView.bounds
                    pulseLayer.cornerRadius = finalSize / 2.0
                    pulseLayer.backgroundColor = isSelected ? NSColor.white.withAlphaComponent(0.25).cgColor : color.withAlphaComponent(0.12).cgColor
                    pulseLayer.borderColor = isSelected ? NSColor.white.withAlphaComponent(0.6).cgColor : color.withAlphaComponent(0.35).cgColor
                    pulseLayer.borderWidth = isSelected ? 1.0 : 0.6
                    
                    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
                    scaleAnim.fromValue = 1.0
                    scaleAnim.toValue = isSelected ? 1.5 : 1.7
                    
                    let opacityAnim = CABasicAnimation(keyPath: "opacity")
                    opacityAnim.fromValue = isSelected ? 0.85 : 0.45
                    opacityAnim.toValue = 0.0
                    
                    let animGroup = CAAnimationGroup()
                    animGroup.animations = [scaleAnim, opacityAnim]
                    animGroup.duration = isSelected ? 2.0 : 4.0
                    animGroup.repeatCount = .infinity
                    animGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    
                    pulseLayer.add(animGroup, forKey: "heatmap_pulse")
                    backingView.layer?.addSublayer(pulseLayer)
                }
                
                // Solid center core dot
                let coreDotSize = isSelected ? max(5, min(9, 2.5 + log2(Double(count)) * 1.0)) : max(3, min(6, 1.2 + log2(Double(count)) * 0.8))
                let coreDot = PassThroughView(frame: CGRect(
                    x: (finalSize - coreDotSize) / 2.0,
                    y: (finalSize - coreDotSize) / 2.0,
                    width: coreDotSize,
                    height: coreDotSize
                ))
                coreDot.wantsLayer = true
                coreDot.layer?.backgroundColor = NSColor.white.cgColor
                coreDot.layer?.cornerRadius = coreDotSize / 2.0
                coreDot.layer?.shadowColor = NSColor.white.cgColor
                coreDot.layer?.shadowRadius = isSelected ? 3 : 1.5
                coreDot.layer?.shadowOpacity = 0.85
                coreDot.layer?.shadowOffset = .zero
                
                backingView.addSubview(coreDot)
                annotationView?.addSubview(backingView)
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let heatmapCircle = overlay as? HeatmapCircle {
                let count = heatmapCircle.clusterCount
                let maxCount = self.lastMaxCount
                return HeatmapOverlayRenderer(circle: heatmapCircle, count: count, maxCount: maxCount)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? PhotoClusterAnnotation else { return }
            
            // Center smoothly on selection without zooming in and causing immediate split
            let region = MKCoordinateRegion(center: annotation.coordinate, span: mapView.region.span)
            mapView.setRegion(region, animated: true)
            
            DispatchQueue.main.async {
                self.parent.selectedCluster = annotation.cluster
            }
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            DispatchQueue.main.async {
                if self.parent.selectedCluster?.id == (view.annotation as? PhotoClusterAnnotation)?.cluster.id {
                    self.parent.selectedCluster = nil
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.currentRegion = mapView.region
            }
        }
    }
}

// MARK: - Annotation Class
class PhotoClusterAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let cluster: MappedCluster
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, cluster: MappedCluster) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.cluster = cluster
    }
}

// MARK: - Main Interactive Heatmap Dashboard View
struct PhotosHeatmapView: View {
    @ObservedObject var manager: PhotosLibraryManager
    
    @State private var selectedCluster: MappedCluster? = nil
    @State private var mapType: MKMapType = .standard
    @State private var centerTrigger: MKCoordinateRegion? = nil
    @State private var searchQuery: String = ""
    @State private var activeStyleSelection: MapStyleSelection = .standard
    @State private var currentRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 120.0, longitudeDelta: 120.0)
    )
    @State private var isSidebarVisible: Bool = true
    @State private var isStyleMenuExpanded: Bool = false
    
    enum HotspotGrouping: String, CaseIterable, Identifiable {
        case city = "City"
        case country = "Country"
        
        var id: String { rawValue }
    }
    @State private var hotspotGrouping: HotspotGrouping = .city
    
    enum VisualizationMode: String, CaseIterable, Identifiable {
        case points = "Points"
        case heatmap = "Heatmap"
        
        var id: String { rawValue }
    }
    @State private var visualizationMode: VisualizationMode = .heatmap
    
    enum MapStyleSelection: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case satellite = "Satellite"
        case hybrid = "Hybrid"
        
        var id: String { rawValue }
        
        var mkType: MKMapType {
            switch self {
            case .standard: return .standard
            case .satellite: return .satellite
            case .hybrid: return .hybrid
            }
        }
    }
    
    var body: some View {
        HStack(spacing: isSidebarVisible ? 24 : 0) {
            // MARK: - Left Hotspots Sidebar
            if isSidebarVisible {
                GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    // Header, Grouping, & Search Panel
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Interactive Hotspots")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Search and fly to density hubs in your library")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Picker("Grouping", selection: $hotspotGrouping) {
                            ForEach(HotspotGrouping.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        
                        // Search Bar
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                            
                            TextField("Search locations...", text: $searchQuery)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                            
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    // Hotspots List (utilizes full vertical space)
                    if filteredClusters.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "mappin.slash")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(searchQuery.isEmpty ? "No mapped photos in current range." : "No matching location found.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(filteredClusters.enumerated()), id: \.element.id) { index, cluster in
                                    Button(action: {
                                        flyToCluster(cluster)
                                    }) {
                                        HStack(spacing: 12) {
                                            // Rank Badge
                                            ZStack {
                                                Circle()
                                                    .fill(badgeColor(for: index).opacity(0.15))
                                                    .frame(width: 28, height: 28)
                                                Text("#\(index + 1)")
                                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                                    .foregroundColor(badgeColor(for: index))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(cluster.cityName)
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                                Text(cluster.countryName)
                                                    .font(.system(size: 9.5))
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            // Capture Count Badge
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("\(cluster.count)")
                                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                    .foregroundColor(.emerald)
                                                Text("shots")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.emerald.opacity(0.08))
                                            .cornerRadius(6)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(selectedCluster?.id == cluster.id ? Color.emerald.opacity(0.12) : Color.white.opacity(0.02))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(selectedCluster?.id == cluster.id ? Color.emerald.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .glassCardHoverEffect(cornerRadius: 10)
                                }
                            }
                        }
                    }
                    
                    // Summary KPIs in sidebar
                    VStack(spacing: 10) {
                        Divider().background(Color.white.opacity(0.06))
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total Geotagged")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text("\(totalMappedPhotosCount) photos")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Map Centers")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text("\(clusters.count) hubs")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 14)
                }
                .frame(width: 300)
                .glassCardHoverEffect()
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            
            // MARK: - Right Map Display Area
            ZStack(alignment: .bottomLeading) {
                // The actual interactive map wrapper
                HeatmapMapView(
                    clusters: mapClusters,
                    selectedCluster: $selectedCluster,
                    mapType: $mapType,
                    centerTrigger: $centerTrigger,
                    currentRegion: $currentRegion,
                    visualizationMode: visualizationMode
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                if isStyleMenuExpanded {
                    Color.black.opacity(0.01)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                isStyleMenuExpanded = false
                            }
                        }
                }
                
                // Top HUD: Sidebar toggle on the left, Zoom controls on the right (perfectly aligned)
                HStack(alignment: .center) {
                    // Places Toggle Button
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isSidebarVisible.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("Places")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .glassCardHoverEffect(cornerRadius: 8)
                    
                    Spacer()
                    
                    // Zoom Controllers
                    HStack(spacing: 8) {
                        Button(action: zoomIn) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .glassCardHoverEffect(cornerRadius: 6)
                        
                        Button(action: zoomOut) {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .glassCardHoverEffect(cornerRadius: 6)
                        
                        Button(action: fitAll) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Fit Mapped")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .frame(height: 28)
                            .padding(.horizontal, 10)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .glassCardHoverEffect(cornerRadius: 6)
                    }
                    .foregroundColor(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // Floating Collapsible Style Picker HUD in Bottom-Right
                VStack(alignment: .trailing, spacing: 8) {
                    if isStyleMenuExpanded {
                        GlassCard(cornerRadius: 12, shadowRadius: 8) {
                            VStack(alignment: .leading, spacing: 12) {
                                // Map Layer Section
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Map Style")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    ForEach(MapStyleSelection.allCases) { style in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                                activeStyleSelection = style
                                                mapType = style.mkType
                                            }
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: styleIcon(for: style))
                                                    .font(.system(size: 9))
                                                    .foregroundColor(activeStyleSelection == style ? .emerald : .secondary)
                                                    .frame(width: 14)
                                                
                                                Text(style.rawValue)
                                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                    .foregroundColor(activeStyleSelection == style ? .emerald : .white.opacity(0.95))
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                if activeStyleSelection == style {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.emerald)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity)
                                            .background(activeStyleSelection == style ? Color.emerald.opacity(0.10) : Color.white.opacity(0.02))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(activeStyleSelection == style ? Color.emerald.opacity(0.3) : Color.clear, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .glassCardHoverEffect(cornerRadius: 6)
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                // Visual Style Section
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Visual Mode")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    ForEach(VisualizationMode.allCases) { mode in
                                        Button(action: {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                                visualizationMode = mode
                                            }
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: modeIcon(for: mode))
                                                    .font(.system(size: 9))
                                                    .foregroundColor(visualizationMode == mode ? .emerald : .secondary)
                                                    .frame(width: 14)
                                                
                                                Text(mode.rawValue)
                                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                    .foregroundColor(visualizationMode == mode ? .emerald : .white.opacity(0.95))
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                if visualizationMode == mode {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.emerald)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .frame(maxWidth: .infinity)
                                            .background(visualizationMode == mode ? Color.emerald.opacity(0.10) : Color.white.opacity(0.02))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(visualizationMode == mode ? Color.emerald.opacity(0.3) : Color.clear, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .glassCardHoverEffect(cornerRadius: 6)
                                    }
                                }
                            }
                            .padding(10)
                            .frame(width: 160)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isStyleMenuExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "square.3.stack.3d")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .glassCardHoverEffect(cornerRadius: 8)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                
                // Floating Details Popup in Bottom-Left
                if let cluster = selectedCluster {
                    GlassCard(cornerRadius: 14, shadowRadius: 10) {
                        VStack(alignment: .leading, spacing: 14) {
                            // Header Location
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(cluster.cityName)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(cluster.countryName)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: { selectedCluster = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Divider().background(Color.white.opacity(0.06))
                            
                            // Metrics Grid
                            HStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Captures")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text("\(cluster.count)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Composition")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text("\(cluster.photoCount) Ph • \(cluster.videoCount) Vi")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.emerald)
                                }
                            }
                            
                            // Cameras used
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gear Utilized")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(cluster.camerasUsed.joined(separator: ", "))
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(2)
                            }
                            
                            // Dates captured
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Capture Window")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(cluster.dateRangeFormatted)
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Altitude presence
                            if let maxAltPhoto = cluster.photos.compactMap({ $0.altitude }).max(), maxAltPhoto > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Peak Altitude")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Text(String(format: "%.0f meters", maxAltPhoto))
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.cyan)
                                }
                            }
                            
                            // Individual Photos List
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Captures in Hub")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                ScrollView(.vertical, showsIndicators: true) {
                                    VStack(spacing: 4) {
                                        ForEach(cluster.photos) { photo in
                                            HStack(spacing: 6) {
                                                Image(systemName: photo.mediaType == "Video" ? "video.fill" : "photo.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.emerald.opacity(0.7))
                                                
                                                Text(photo.filename)
                                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.85))
                                                    .lineLimit(1)
                                                
                                                Spacer()
                                                
                                                if manager.sourceMode == .direct {
                                                    Button(action: {
                                                        manager.revealPhotoInPhotosApp(photoId: photo.id)
                                                    }) {
                                                        Image(systemName: "arrow.up.forward.app")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(.emerald)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .help("Reveal photo in Photos app")
                                                }
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.03))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                                .frame(height: 90)
                                .padding(4)
                                .background(Color.black.opacity(0.15))
                                .cornerRadius(6)
                            }
                            
                            // Fly to Zoom closer
                            Button(action: {
                                zoomCloserTo(cluster)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 10))
                                    Text("Detailed Zoom")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Color.emerald.opacity(0.75))
                                .cornerRadius(6)
                                .shadow(color: .emerald.opacity(0.2), radius: 3)
                            }
                            .buttonStyle(.plain)
                            .glassCardHoverEffect(cornerRadius: 6)
                        }
                        .padding(16)
                    }
                    .frame(width: 290)
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(), value: selectedCluster)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                fitAll()
            }
        }
    }
    
    // MARK: - Calculations
    
    // Dynamic granularity clusters computed on the map visible span delta
    private var mapClusters: [MappedCluster] {
        let zoom = MapZoomLevel.level(forDelta: currentRegion.span.latitudeDelta)
        return manager.precomputedMapClusters[zoom] ?? []
    }
    
    // Clusters computed on the current filtered photos array (constant city/country-level for sidebar)
    private var clusters: [MappedCluster] {
        hotspotGrouping == .city ? manager.precomputedCityClusters : manager.precomputedCountryClusters
    }
    
    private var filteredClusters: [MappedCluster] {
        if searchQuery.isEmpty {
            return clusters
        } else {
            let lowerQuery = searchQuery.lowercased()
            return clusters.filter {
                $0.cityName.lowercased().contains(lowerQuery) ||
                $0.countryName.lowercased().contains(lowerQuery)
            }
        }
    }
    
    private var totalMappedPhotosCount: Int {
        clusters.map { $0.count }.reduce(0, +)
    }
    
    // MARK: - Actions
    
    private func flyToCluster(_ cluster: MappedCluster) {
        selectedCluster = cluster
        let delta = hotspotGrouping == .city ? 0.6 : 12.0
        let region = MKCoordinateRegion(
            center: cluster.coordinate,
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
        centerTrigger = region
    }
    
    private func zoomCloserTo(_ cluster: MappedCluster) {
        let region = MKCoordinateRegion(
            center: cluster.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
        centerTrigger = region
    }
    
    private func fitAll() {
        guard !clusters.isEmpty else { return }
        
        let lats = clusters.map { $0.coordinate.latitude }
        let lons = clusters.map { $0.coordinate.longitude }
        
        let minLat = lats.min() ?? 0.0
        let maxLat = lats.max() ?? 0.0
        let minLon = lons.min() ?? 0.0
        let maxLon = lons.max() ?? 0.0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        
        let latDelta = max(6.0, (maxLat - minLat) * 1.5)
        let lonDelta = max(6.0, (maxLon - minLon) * 1.5)
        
        // Cap deltas to stay on globe
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: min(latDelta, 140.0),
                longitudeDelta: min(lonDelta, 300.0)
            )
        )
        centerTrigger = region
    }
    
    private func zoomIn() {
        let current = currentRegion
        let nextSpan = MKCoordinateSpan(
            latitudeDelta: max(0.002, current.span.latitudeDelta / 2.5),
            longitudeDelta: max(0.002, current.span.longitudeDelta / 2.5)
        )
        centerTrigger = MKCoordinateRegion(center: current.center, span: nextSpan)
    }
    
    private func zoomOut() {
        let current = currentRegion
        let nextSpan = MKCoordinateSpan(
            latitudeDelta: min(140.0, current.span.latitudeDelta * 2.5),
            longitudeDelta: min(300.0, current.span.longitudeDelta * 2.5)
        )
        centerTrigger = MKCoordinateRegion(center: current.center, span: nextSpan)
    }
    
    // Sidebar colors helper
    private func badgeColor(for index: Int) -> Color {
        switch index {
        case 0: return .emerald
        case 1: return .cyan
        case 2: return .orange
        default: return .secondary
        }
    }
    
    private func styleIcon(for style: MapStyleSelection) -> String {
        switch style {
        case .standard: return "map.fill"
        case .satellite: return "globe.americas.fill"
        case .hybrid: return "square.3.stack.3d.top.filled"
        }
    }
    
    private func modeIcon(for mode: VisualizationMode) -> String {
        switch mode {
        case .points: return "circle.circle.fill"
        case .heatmap: return "square.3.stack.3d.middle.filled"
        }
    }
}
