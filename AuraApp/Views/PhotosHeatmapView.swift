import SwiftUI
import MapKit
import AppKit

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
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsZoomControls = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.mapType = mapType
        return mapView
    }
    
    func updateNSView(_ nsView: MKMapView, context: Context) {
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
            // Calculate scale sizing based on photo count (log scale)
            let baseSize = CGFloat(max(20, min(54, 16 + log2(Double(count)) * 6.5)))
            
            annotationView?.frame = CGRect(x: 0, y: 0, width: baseSize, height: baseSize)
            
            // Clean up any existing subviews or sublayers
            annotationView?.subviews.forEach { $0.removeFromSuperview() }
            annotationView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            // Setup core background view
            let backingView = NSView(frame: annotationView?.bounds ?? .zero)
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
            
            backingView.layer?.backgroundColor = color.withAlphaComponent(0.55).cgColor
            backingView.layer?.cornerRadius = baseSize / 2.0
            backingView.layer?.borderColor = color.withAlphaComponent(0.9).cgColor
            backingView.layer?.borderWidth = 1.5
            
            // Glowing shadow effect
            backingView.layer?.shadowColor = color.cgColor
            backingView.layer?.shadowRadius = 8
            backingView.layer?.shadowOpacity = 0.8
            backingView.layer?.shadowOffset = .zero
            
            // Pulsing Ring Animation
            let pulseLayer = CALayer()
            pulseLayer.frame = backingView.bounds
            pulseLayer.cornerRadius = baseSize / 2.0
            pulseLayer.backgroundColor = color.withAlphaComponent(0.3).cgColor
            pulseLayer.borderColor = color.withAlphaComponent(0.65).cgColor
            pulseLayer.borderWidth = 1.2
            
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 1.0
            scaleAnim.toValue = 1.65
            
            let opacityAnim = CABasicAnimation(keyPath: "opacity")
            opacityAnim.fromValue = 0.85
            opacityAnim.toValue = 0.0
            
            let animGroup = CAAnimationGroup()
            animGroup.animations = [scaleAnim, opacityAnim]
            animGroup.duration = 2.4
            animGroup.repeatCount = .infinity
            animGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            pulseLayer.add(animGroup, forKey: "heatmap_pulse")
            backingView.layer?.addSublayer(pulseLayer)
            
            // Solid center core dot
            let coreDotSize = max(6, min(12, 4 + log2(Double(count)) * 1.5))
            let coreDot = NSView(frame: CGRect(
                x: (baseSize - coreDotSize) / 2.0,
                y: (baseSize - coreDotSize) / 2.0,
                width: coreDotSize,
                height: coreDotSize
            ))
            coreDot.wantsLayer = true
            coreDot.layer?.backgroundColor = NSColor.white.cgColor
            coreDot.layer?.cornerRadius = coreDotSize / 2.0
            coreDot.layer?.shadowColor = NSColor.white.cgColor
            coreDot.layer?.shadowRadius = 3
            coreDot.layer?.shadowOpacity = 0.9
            coreDot.layer?.shadowOffset = .zero
            
            backingView.addSubview(coreDot)
            annotationView?.addSubview(backingView)
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? PhotoClusterAnnotation else { return }
            
            // Zoom smoothly to centered region on selection
            let currentSpan = mapView.region.span
            let targetSpan = MKCoordinateSpan(
                latitudeDelta: min(currentSpan.latitudeDelta, 12.0),
                longitudeDelta: min(currentSpan.longitudeDelta, 12.0)
            )
            let region = MKCoordinateRegion(center: annotation.coordinate, span: targetSpan)
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
        HStack(spacing: 24) {
            // MARK: - Left Hotspots Sidebar
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
            
            // MARK: - Right Map Display Area
            ZStack(alignment: .bottomLeading) {
                // The actual interactive map wrapper
                HeatmapMapView(
                    clusters: clusters,
                    selectedCluster: $selectedCluster,
                    mapType: $mapType,
                    centerTrigger: $centerTrigger
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                
                // Floating Style and Zoom HUD in Top-Right
                VStack(spacing: 12) {
                    // Map Style Picker
                    Picker("", selection: $activeStyleSelection) {
                        ForEach(MapStyleSelection.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    .onChange(of: activeStyleSelection) { newValue in
                        mapType = newValue.mkType
                    }
                    .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
                    .cornerRadius(8)
                    .shadow(radius: 6)
                    
                    // Zoom Controllers
                    HStack(spacing: 8) {
                        Button(action: zoomIn) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .glassCardHoverEffect(cornerRadius: 6)
                        
                        Button(action: zoomOut) {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .glassCardHoverEffect(cornerRadius: 6)
                        
                        Button(action: fitAll) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                                    .font(.system(size: 10, weight: .bold))
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                
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
    
    // Clusters computed on the current filtered photos array
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
        // We will trigger a change via centerTrigger. To zoom in, we can divide the delta by 2.
        // If we don't have a specific location, we zoom in to center.
        let targetCenter = selectedCluster?.coordinate ?? CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0)
        let delta: Double = selectedCluster != nil ? 4.0 : 30.0
        let region = MKCoordinateRegion(
            center: targetCenter,
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
        centerTrigger = region
    }
    
    private func zoomOut() {
        let targetCenter = selectedCluster?.coordinate ?? CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0)
        let delta: Double = selectedCluster != nil ? 30.0 : 120.0
        let region = MKCoordinateRegion(
            center: targetCenter,
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
        centerTrigger = region
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
