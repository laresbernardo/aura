import SwiftUI
import MapKit
import AppKit

// MARK: - Pass Through View for Mouse Events
class PassThroughView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

// MARK: - Mapped Cluster Model
struct MappedCluster: Identifiable, Equatable {
    let id: String // City, Country or formatted Coordinate
    let cityName: String
    let countryName: String
    let coordinate: CLLocationCoordinate2D
    let photos: [Photo]
    
    var count: Int { photos.count }
    
    var photoCount: Int {
        photos.filter { $0.mediaType == "Photo" }.count
    }
    
    var videoCount: Int {
        photos.filter { $0.mediaType == "Video" }.count
    }
    
    var camerasUsed: [String] {
        let models = photos.compactMap { $0.cameraModel }
        return Array(Set(models)).sorted()
    }
    
    var dateRangeFormatted: String {
        guard !photos.isEmpty else { return "No date" }
        let dates = photos.map(\.dateAdded)
        let minDate = Date(timeIntervalSince1970: dates.min() ?? 0)
        let maxDate = Date(timeIntervalSince1970: dates.max() ?? 0)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        // If same day
        if Calendar.current.isDate(minDate, inSameDayAs: maxDate) {
            return formatter.string(from: minDate)
        }
        
        return "\(formatter.string(from: minDate)) – \(formatter.string(from: maxDate))"
    }
    
    static func == (lhs: MappedCluster, rhs: MappedCluster) -> Bool {
        lhs.id == rhs.id && lhs.count == rhs.count
    }
}

// MARK: - Native MKMapView Wrapper with Pulsing Heatmap Circles
struct HeatmapMapView: NSViewRepresentable {
    let clusters: [MappedCluster]
    @Binding var selectedCluster: MappedCluster?
    @Binding var mapType: MKMapType
    @Binding var centerTrigger: MKCoordinateRegion?
    @Binding var currentRegion: MKCoordinateRegion
    
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
            
            // Calculate scale sizing based on photo count (log scale) - reduced size to prevent map clutter
            let baseSize = CGFloat(max(10, min(30, 6 + log2(Double(count)) * 3.0)))
            let finalSize = isSelected ? baseSize * 1.35 + 4 : baseSize
            
            annotationView?.frame = CGRect(x: 0, y: 0, width: finalSize, height: finalSize)
            
            // Clean up any existing subviews or sublayers
            annotationView?.subviews.forEach { $0.removeFromSuperview() }
            annotationView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            // Setup core background view
            let backingView = PassThroughView(frame: annotationView?.bounds ?? .zero)
            backingView.wantsLayer = true
            
            // Determine density color theme
            let color: NSColor
            if count <= 5 {
                color = NSColor.systemTeal // Low density
            } else if count <= 25 {
                color = NSColor.systemOrange // Medium density
            } else {
                color = NSColor.systemRed // High density
            }
            
            // Softer opacity, border, and shadows to render as a soft heatmap layer
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
            
            return annotationView
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
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Interactive Hotspots")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Search and fly to density hubs in your library")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
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
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    // Hotspots List
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
                            LazyVStack(spacing: 10) {
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
                    
                    Spacer()
                    
                    // Summary KPIs in sidebar
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
                    .padding(.top, 4)
                }
                .padding(20)
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
                    currentRegion: $currentRegion
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                // Top HUD: Sidebar toggle on the left, Zoom controls on the right (perfectly aligned)
                HStack(alignment: .center) {
                    // Sidebar Toggle Button
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isSidebarVisible.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("Sidebar")
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
                        VStack(spacing: 6) {
                            ForEach(MapStyleSelection.allCases) { style in
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        activeStyleSelection = style
                                        mapType = style.mkType
                                        isStyleMenuExpanded = false
                                    }
                                }) {
                                    Text(style.rawValue)
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundColor(activeStyleSelection == style ? .emerald : .white.opacity(0.85))
                                        .frame(width: 80, height: 24)
                                        .background(activeStyleSelection == style ? Color.emerald.opacity(0.12) : Color.clear)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
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
                    .frame(width: 240)
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
        let delta = currentRegion.span.latitudeDelta
        var dict: [String: [Photo]] = [:]
        
        for photo in manager.photos {
            guard let lat = photo.latitude, let lon = photo.longitude else { continue }
            
            let key: String
            if delta > 40.0 {
                // World Zoom: Group by Country
                key = photo.countryName ?? "Unknown Country"
            } else if delta > 8.0 {
                // Continent/Country Zoom: Group by City/Country
                if let city = photo.cityName, let country = photo.countryName {
                    key = "\(city), \(country)"
                } else {
                    key = String(format: "%.1f,%.1f", lat, lon)
                }
            } else if delta > 2.0 {
                // Regional/State Zoom: Group by 1 decimal place (~11km)
                key = String(format: "%.1f,%.1f", lat, lon)
            } else if delta > 0.4 {
                // City Zoom: Group by 2 decimal places (~1.1km)
                key = String(format: "%.2f,%.2f", lat, lon)
            } else if delta > 0.08 {
                // Neighborhood Zoom: Group by 3 decimal places (~110m)
                key = String(format: "%.3f,%.3f", lat, lon)
            } else {
                // Street/Block Zoom: Group by 4 decimal places (~11m)
                key = String(format: "%.4f,%.4f", lat, lon)
            }
            
            dict[key, default: []].append(photo)
        }
        
        return dict.compactMap { key, clusterPhotos -> MappedCluster? in
            guard let first = clusterPhotos.first,
                  first.latitude != nil,
                  first.longitude != nil else { return nil }
            
            // Average coordinate position
            let avgLat = clusterPhotos.map { $0.latitude ?? 0.0 }.reduce(0.0, +) / Double(clusterPhotos.count)
            let avgLon = clusterPhotos.map { $0.longitude ?? 0.0 }.reduce(0.0, +) / Double(clusterPhotos.count)
            
            let baseCityName = first.cityName ?? "Unknown Region"
            let countryName = first.countryName ?? "Unknown Country"
            
            return MappedCluster(
                id: key,
                cityName: baseCityName,
                countryName: countryName,
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                photos: clusterPhotos
            )
        }.sorted(by: { $0.count > $1.count })
    }
    
    // Clusters computed on the current filtered photos array (constant city-level for sidebar)
    private var clusters: [MappedCluster] {
        var dict: [String: [Photo]] = [:]
        
        for photo in manager.photos {
            guard let lat = photo.latitude, let lon = photo.longitude else { continue }
            
            let key: String
            if let city = photo.cityName, let country = photo.countryName {
                key = "\(city), \(country)"
            } else {
                key = String(format: "%.1f,%.1f", lat, lon)
            }
            
            dict[key, default: []].append(photo)
        }
        
        return dict.compactMap { key, clusterPhotos -> MappedCluster? in
            guard let first = clusterPhotos.first,
                  first.latitude != nil,
                  first.longitude != nil else { return nil }
            
            // Average coordinate position
            let avgLat = clusterPhotos.map { $0.latitude ?? 0.0 }.reduce(0.0, +) / Double(clusterPhotos.count)
            let avgLon = clusterPhotos.map { $0.longitude ?? 0.0 }.reduce(0.0, +) / Double(clusterPhotos.count)
            
            let cityName = first.cityName ?? "Unknown Region"
            let countryName = first.countryName ?? "Unknown Country"
            
            return MappedCluster(
                id: key,
                cityName: cityName,
                countryName: countryName,
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                photos: clusterPhotos
            )
        }.sorted(by: { $0.count > $1.count })
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
        let region = MKCoordinateRegion(
            center: cluster.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
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
}
