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
    let photos: [Photo]
    @Binding var selectedCluster: MappedCluster?
    @Binding var mapType: MKMapType
    @Binding var centerTrigger: MKCoordinateRegion?
    @Binding var currentRegion: MKCoordinateRegion
    let visualizationMode: PhotosHeatmapView.VisualizationMode
    let isPlaybackActive: Bool
    @Binding var userPreferredSpan: MKCoordinateSpan
    @Binding var isPlaybackPlaying: Bool
    
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
        
        // 1. Sync Annotations via optimized diffing to prevent flickering
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
        
        if existingKeys != newKeys || existingAnnotations.map({ $0.cluster.count }) != newAnnotations.map({ $0.cluster.count }) {
            let toRemove = existingAnnotations.filter { !newKeys.contains($0.cluster.id) }
            if !toRemove.isEmpty {
                nsView.removeAnnotations(toRemove)
            }
            
            let toAdd = newAnnotations.filter { !existingKeys.contains($0.cluster.id) }
            if !toAdd.isEmpty {
                nsView.addAnnotations(toAdd)
            }
            
            let toUpdate = newAnnotations.filter { ann in
                if let existing = existingAnnotations.first(where: { $0.cluster.id == ann.cluster.id }) {
                    return existing.cluster.count != ann.cluster.count
                }
                return false
            }
            
            if !toUpdate.isEmpty {
                let toRemoveForUpdate = existingAnnotations.filter { ext in
                    toUpdate.contains(where: { $0.cluster.id == ext.cluster.id })
                }
                nsView.removeAnnotations(toRemoveForUpdate)
                nsView.addAnnotations(toUpdate)
            }
        }
        
        // 1b. Sync Overlays
        if visualizationMode == .heatmap {
            let existingPolylines = nsView.overlays.compactMap { $0 as? MKPolyline }
            if !existingPolylines.isEmpty {
                nsView.removeOverlays(existingPolylines)
            }
            
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
                nsView.removeOverlays(existingCircles)
                nsView.addOverlays(newOverlays)
            }
        } else if visualizationMode == .routes {
            let existingCircles = nsView.overlays.compactMap { $0 as? HeatmapCircle }
            if !existingCircles.isEmpty {
                nsView.removeOverlays(existingCircles)
            }
            
            // Build the unique coordinates of photos sorted chronologically by timestamp
            let routePhotos = photos
                .filter { $0.latitude != nil && $0.longitude != nil }
                .sorted(by: { $0.dateAdded < $1.dateAdded })
            
            var coordinates: [CLLocationCoordinate2D] = []
            coordinates.reserveCapacity(routePhotos.count)
            for photo in routePhotos {
                let coord = CLLocationCoordinate2D(latitude: photo.latitude!, longitude: photo.longitude!)
                if let last = coordinates.last {
                    if last.latitude == coord.latitude && last.longitude == coord.longitude {
                        continue
                    }
                }
                coordinates.append(coord)
            }
            
            // Sync polyline overlay
            let existingPolylines = nsView.overlays.compactMap { $0 as? MKPolyline }
            
            var needsUpdate = false
            if existingPolylines.count != 1 {
                needsUpdate = true
            } else if let firstPolyline = existingPolylines.first {
                if firstPolyline.pointCount != coordinates.count {
                    needsUpdate = true
                } else if coordinates.count > 0 {
                    var firstCoord = CLLocationCoordinate2D()
                    var lastCoord = CLLocationCoordinate2D()
                    firstPolyline.getCoordinates(&firstCoord, range: NSRange(location: 0, length: 1))
                    firstPolyline.getCoordinates(&lastCoord, range: NSRange(location: coordinates.count - 1, length: 1))
                    
                    if abs(firstCoord.latitude - coordinates.first!.latitude) > 0.000001 ||
                       abs(firstCoord.longitude - coordinates.first!.longitude) > 0.000001 ||
                       abs(lastCoord.latitude - coordinates.last!.latitude) > 0.000001 ||
                       abs(lastCoord.longitude - coordinates.last!.longitude) > 0.000001 {
                        needsUpdate = true
                    }
                }
            }
            
            if needsUpdate {
                nsView.removeOverlays(existingPolylines)
                if !coordinates.isEmpty {
                    var mutableCoords = coordinates
                    let polyline = MKPolyline(coordinates: &mutableCoords, count: coordinates.count)
                    nsView.addOverlay(polyline)
                }
            }
        } else {
            if !nsView.overlays.isEmpty {
                nsView.removeOverlays(nsView.overlays)
            }
        }
        
        // 2. Center/Zoom Trigger
        if let targetRegion = centerTrigger {
            let oldCenter = nsView.centerCoordinate
            let newCenter = targetRegion.center
            let latDistance = abs(oldCenter.latitude - newCenter.latitude)
            let lonDistance = abs(oldCenter.longitude - newCenter.longitude)
            
            // Only perform two-step flyover zoom if the distance is very large (> 15 degrees) and playback is active
            if (latDistance > 15.0 || lonDistance > 15.0) && isPlaybackActive {
                let midLat = (oldCenter.latitude + newCenter.latitude) / 2.0
                let midLon = (oldCenter.longitude + newCenter.longitude) / 2.0
                let midCenter = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)
                
                let wideSpan = MKCoordinateSpan(
                    latitudeDelta: min(179.0, max(latDistance * 1.8, 35.0)),
                    longitudeDelta: min(360.0, max(lonDistance * 1.8, 35.0))
                )
                let wideRegion = MKCoordinateRegion(center: midCenter, span: wideSpan)
                
                nsView.setRegion(wideRegion, animated: true)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    nsView.setRegion(targetRegion, animated: true)
                }
            } else {
                nsView.setRegion(targetRegion, animated: true)
            }
            
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
        
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            guard parent.isPlaybackActive else { return }
            for view in views {
                guard view.annotation is PhotoClusterAnnotation else { continue }
                if let backing = view.subviews.first {
                    backing.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    
                    // 1. Overshooting spring pop animation (scales up to 1.3 then springs back to 1.0)
                    let popAnim = CASpringAnimation(keyPath: "transform.scale")
                    popAnim.fromValue = 0.1
                    popAnim.toValue = 1.0
                    popAnim.damping = 10     // Springier
                    popAnim.stiffness = 140
                    popAnim.mass = 0.8
                    popAnim.duration = popAnim.settlingDuration
                    backing.layer?.add(popAnim, forKey: "pop_spring")
                    
                    // 2. High-visibility transient radar pulse ring
                    let pulseLayer = CALayer()
                    pulseLayer.frame = backing.bounds
                    pulseLayer.cornerRadius = backing.bounds.width / 2.0
                    pulseLayer.borderColor = NSColor.systemCyan.cgColor
                    pulseLayer.borderWidth = 2.0
                    pulseLayer.backgroundColor = NSColor.systemCyan.withAlphaComponent(0.25).cgColor
                    
                    backing.layer?.addSublayer(pulseLayer)
                    
                    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
                    scaleAnim.fromValue = 1.0
                    scaleAnim.toValue = 5.0  // Expand to 5x size
                    
                    let opacityAnim = CABasicAnimation(keyPath: "opacity")
                    opacityAnim.fromValue = 1.0
                    opacityAnim.toValue = 0.0
                    
                    let animGroup = CAAnimationGroup()
                    animGroup.animations = [scaleAnim, opacityAnim]
                    animGroup.duration = 0.9
                    animGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    animGroup.isRemovedOnCompletion = true
                    
                    pulseLayer.add(animGroup, forKey: "radar_pulse")
                    
                    // Remove transient pulse layer after animation finishes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        pulseLayer.removeFromSuperlayer()
                    }
                }
            }
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
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor.systemCyan.withAlphaComponent(0.85) // Glowing Electric Cyan
                renderer.lineWidth = 2.5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
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
                if !self.parent.isPlaybackPlaying {
                    self.parent.userPreferredSpan = mapView.region.span
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
        case routes = "Routes"
        
        var id: String { rawValue }
    }
    @State private var visualizationMode: VisualizationMode = .heatmap
    @State private var selectedDevices: Set<String> = []
    
    // MARK: - Playback and Animation State
    @State private var isPlaybackActive: Bool = false
    @State private var isPlaybackPlaying: Bool = false
    @State private var currentPhotoIndex: Int = 1
    @State private var currentPhotoIndexDouble: Double = 1.0
    @State private var playbackDuration: Double = 10.0
    @State private var autoPanEnabled: Bool = true
    @State private var playbackTimer: Timer? = nil
    @State private var lastCenteredCoordinate: CLLocationCoordinate2D? = nil
    @State private var userPreferredSpan = MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    @State private var previousVisualizationMode: VisualizationMode? = nil
    
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
                    photos: playbackPhotos,
                    selectedCluster: $selectedCluster,
                    mapType: $mapType,
                    centerTrigger: $centerTrigger,
                    currentRegion: $currentRegion,
                    visualizationMode: visualizationMode,
                    isPlaybackActive: isPlaybackActive,
                    userPreferredSpan: $userPreferredSpan,
                    isPlaybackPlaying: $isPlaybackPlaying
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
                HStack(alignment: .center, spacing: 10) {
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
                    
                    // Time Tour Toggle Button
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if isPlaybackActive {
                                closeTour()
                            } else {
                                initializeTour()
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isPlaybackActive ? "clock.arrow.circlepath" : "play.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(isPlaybackActive ? "Exit Tour" : "Time Tour")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(isPlaybackActive ? .emerald : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(isPlaybackActive ? Color.emerald.opacity(0.15) : Color.black.opacity(0.4))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isPlaybackActive ? Color.emerald.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
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
                
                // Date Range Note - Top Centered
                if !visiblePhotos.isEmpty {
                    GlassCard(cornerRadius: 8, shadowRadius: 4, borderColor: Color.white.opacity(0.08), backgroundColor: Color.black.opacity(0.3)) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(visiblePhotosDateRange)
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: visiblePhotosDateRange)
                }
                
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
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                // Device Filter Section
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Device Filter")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    // All Devices Option
                                    Button(action: {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                            selectedDevices.removeAll()
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "cpu")
                                                .font(.system(size: 9))
                                                .foregroundColor(selectedDevices.isEmpty ? .emerald : .secondary)
                                                .frame(width: 14)
                                            
                                            Text("All Devices")
                                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                .foregroundColor(selectedDevices.isEmpty ? .emerald : .white.opacity(0.95))
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            if selectedDevices.isEmpty {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.emerald)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedDevices.isEmpty ? Color.emerald.opacity(0.10) : Color.white.opacity(0.02))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedDevices.isEmpty ? Color.emerald.opacity(0.3) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .glassCardHoverEffect(cornerRadius: 6)
                                    
                                    if !availableDevices.isEmpty {
                                        ScrollView(.vertical, showsIndicators: false) {
                                            VStack(spacing: 4) {
                                                ForEach(availableDevices, id: \.self) { device in
                                                    Button(action: {
                                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                                            if selectedDevices.contains(device) {
                                                                selectedDevices.remove(device)
                                                            } else {
                                                                selectedDevices.insert(device)
                                                            }
                                                        }
                                                    }) {
                                                        HStack(spacing: 8) {
                                                            Image(systemName: deviceIcon(for: device))
                                                                .font(.system(size: 9))
                                                                .foregroundColor(selectedDevices.contains(device) ? .emerald : .secondary)
                                                                .frame(width: 14)
                                                            
                                                            Text(device)
                                                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                                .foregroundColor(selectedDevices.contains(device) ? .emerald : .white.opacity(0.95))
                                                                .lineLimit(1)
                                                            
                                                            Spacer()
                                                            
                                                            // Small monospaced counter badge
                                                            if let count = devicePhotoCounts[device] {
                                                                Text("\(count)")
                                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                                    .lineLimit(1)
                                                                    .fixedSize(horizontal: true, vertical: false)
                                                                    .foregroundColor(selectedDevices.contains(device) ? .emerald.opacity(0.85) : .secondary.opacity(0.8))
                                                                    .padding(.horizontal, 5)
                                                                    .padding(.vertical, 1.5)
                                                                    .background(Color.white.opacity(0.04))
                                                                    .cornerRadius(4)
                                                            }
                                                            
                                                            if selectedDevices.contains(device) {
                                                                Image(systemName: "checkmark")
                                                                    .font(.system(size: 9, weight: .bold))
                                                                    .foregroundColor(.emerald)
                                                            }
                                                        }
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 6)
                                                        .frame(maxWidth: .infinity)
                                                        .background(selectedDevices.contains(device) ? Color.emerald.opacity(0.10) : Color.white.opacity(0.02))
                                                        .cornerRadius(6)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 6)
                                                                .stroke(selectedDevices.contains(device) ? Color.emerald.opacity(0.3) : Color.clear, lineWidth: 1)
                                                        )
                                                    }
                                                    .buttonStyle(.plain)
                                                    .glassCardHoverEffect(cornerRadius: 6)
                                                }
                                            }
                                        }
                                        .frame(maxHeight: 120)
                                    }
                                }
                            }
                             .padding(10)
                             .frame(width: 220)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isStyleMenuExpanded.toggle()
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "square.3.stack.3d")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                            
                            if !selectedDevices.isEmpty {
                                Circle()
                                    .fill(Color.emerald)
                                    .frame(width: 6.5, height: 6.5)
                                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 0.5))
                                    .offset(x: -2, y: 2)
                                    .shadow(color: .emerald.opacity(0.8), radius: 2)
                            }
                        }
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
                                     LazyVStack(spacing: 4) {
                                         ForEach(cluster.photos) { photo in
                                             HStack(spacing: 6) {
                                                 PhotoThumbnailView(photoId: photo.id, sourceMode: manager.sourceMode)
                                                 
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
                                             .photoPreviewHover(photo: photo, sourceMode: manager.sourceMode)
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
                
                // Floating Playback Control HUD in Bottom-Center
                if isPlaybackActive {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            playbackCardView
                            Spacer()
                        }
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(5)
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
    
    private func isCoordinate(_ coord: CLLocationCoordinate2D, inside region: MKCoordinateRegion) -> Bool {
        let latMin = region.center.latitude - region.span.latitudeDelta / 2.0
        let latMax = region.center.latitude + region.span.latitudeDelta / 2.0
        
        let lonMin = region.center.longitude - region.span.longitudeDelta / 2.0
        let lonMax = region.center.longitude + region.span.longitudeDelta / 2.0
        
        if lonMin >= -180.0 && lonMax <= 180.0 {
            return coord.latitude >= latMin && coord.latitude <= latMax &&
                   coord.longitude >= lonMin && coord.longitude <= lonMax
        }
        
        let latOk = coord.latitude >= latMin && coord.latitude <= latMax
        guard latOk else { return false }
        
        let lonMinWrapped = lonMin < -180.0 ? lonMin + 360.0 : lonMin
        let lonMaxWrapped = lonMax > 180.0 ? lonMax - 360.0 : lonMax
        
        if lonMin < -180.0 {
            return coord.longitude >= lonMinWrapped || coord.longitude <= lonMax
        } else {
            return coord.longitude >= lonMin || coord.longitude <= lonMaxWrapped
        }
    }
    
    private var visiblePhotos: [Photo] {
        let photosToCheck = isPlaybackActive ? playbackPhotos : filteredPhotosForMap
        return photosToCheck.filter { photo in
            guard let lat = photo.latitude, let lon = photo.longitude else { return false }
            return isCoordinate(CLLocationCoordinate2D(latitude: lat, longitude: lon), inside: currentRegion)
        }
    }
    
    private var visiblePhotosDateRange: String {
        let photos = visiblePhotos
        guard !photos.isEmpty else { return "" }
        let dates = photos.map(\.dateAdded)
        let minDate = Date(timeIntervalSince1970: dates.min() ?? 0)
        let maxDate = Date(timeIntervalSince1970: dates.max() ?? 0)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if Calendar.current.isDate(minDate, inSameDayAs: maxDate) {
            return formatter.string(from: minDate)
        }
        return "\(formatter.string(from: minDate)) – \(formatter.string(from: maxDate))"
    }
    
    private var devicePhotoCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for photo in manager.photos {
            if photo.latitude != nil && photo.longitude != nil, let model = photo.cameraModel {
                counts[model, default: 0] += 1
            }
        }
        return counts
    }
    
    private func filterClusters(_ clusters: [MappedCluster]) -> [MappedCluster] {
        guard !selectedDevices.isEmpty else { return clusters }
        return clusters.compactMap { cluster in
            let filteredPhotos = cluster.photos.filter { photo in
                if let model = photo.cameraModel {
                    return selectedDevices.contains(model)
                }
                return false
            }
            guard !filteredPhotos.isEmpty else { return nil }
            return MappedCluster(
                id: cluster.id,
                cityName: cluster.cityName,
                countryName: cluster.countryName,
                coordinate: cluster.coordinate,
                photos: filteredPhotos
            )
        }
    }
    
    // Playback specific calculations and helpers
    private var photosInPeriodCount: Int {
        filteredPhotosForMap.count
    }
    
    private var geotaggedPhotosInPeriod: [Photo] {
        filteredPhotosForMap.filter { $0.latitude != nil && $0.longitude != nil }
    }
    
    private var geotaggedPhotosCount: Int {
        geotaggedPhotosInPeriod.count
    }
    
    private var nonGeotaggedPhotosCount: Int {
        photosInPeriodCount - geotaggedPhotosCount
    }
    
    private var sortedPhotos: [Photo] {
        geotaggedPhotosInPeriod.sorted(by: { $0.dateAdded < $1.dateAdded })
    }
    
    private var progressPercentage: Double {
        guard sortedPhotos.count > 1,
              let firstDate = sortedPhotos.first?.dateAdded,
              let lastDate = sortedPhotos.last?.dateAdded else {
            return 0.0
        }
        let activePhoto = sortedPhotos[min(currentPhotoIndex - 1, sortedPhotos.count - 1)]
        let totalDelta = lastDate - firstDate
        guard totalDelta > 0 else { return 0.0 }
        return (activePhoto.dateAdded - firstDate) / totalDelta
    }
    
    private var playbackPhotos: [Photo] {
        let sorted = sortedPhotos
        guard isPlaybackActive else { return sorted }
        let limit = min(currentPhotoIndex, sorted.count)
        return Array(sorted[0..<limit])
    }
    
    private func computeDynamicClusters(for photos: [Photo], at level: MapZoomLevel) -> [MappedCluster] {
        let delta = level.representativeDelta
        var levelDict: [String: [Photo]] = [:]
        for photo in photos {
            guard let lat = photo.latitude, let lon = photo.longitude else { continue }
            let key: String
            if delta > 40.0 {
                key = photo.countryName ?? "Unknown Country"
            } else if delta > 8.0 {
                if let city = photo.cityName, let country = photo.countryName {
                    key = "\(city), \(country)"
                } else {
                    key = String(format: "%.1f,%.1f", lat, lon)
                }
            } else if delta > 2.0 {
                key = String(format: "%.1f,%.1f", lat, lon)
            } else if delta > 0.4 {
                key = String(format: "%.2f,%.2f", lat, lon)
            } else if delta > 0.08 {
                key = String(format: "%.3f,%.3f", lat, lon)
            } else {
                key = String(format: "%.4f,%.4f", lat, lon)
            }
            levelDict[key, default: []].append(photo)
        }
        
        let filteredDict = levelDict.compactMap { key, clusterPhotos -> MappedCluster? in
            guard !clusterPhotos.isEmpty else { return nil }
            let first = clusterPhotos.first!
            let avgLat = clusterPhotos.compactMap(\.latitude).reduce(0.0, +) / Double(clusterPhotos.count)
            let avgLon = clusterPhotos.compactMap(\.longitude).reduce(0.0, +) / Double(clusterPhotos.count)
            return MappedCluster(
                id: key,
                cityName: first.cityName ?? "Unknown Region",
                countryName: first.countryName ?? "Unknown Country",
                coordinate: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                photos: clusterPhotos
            )
        }
        
        return filterClusters(filteredDict)
    }
    
    // Dynamic granularity clusters computed on the map visible span delta
    private var mapClusters: [MappedCluster] {
        let zoom = MapZoomLevel.level(forDelta: currentRegion.span.latitudeDelta)
        if isPlaybackActive {
            return computeDynamicClusters(for: playbackPhotos, at: zoom)
        } else {
            let rawClusters = manager.precomputedMapClusters[zoom] ?? []
            return filterClusters(rawClusters)
        }
    }
    
    // Clusters computed on the current filtered photos array (constant city/country-level for sidebar)
    private var clusters: [MappedCluster] {
        let rawClusters = hotspotGrouping == .city ? manager.precomputedCityClusters : manager.precomputedCountryClusters
        return filterClusters(rawClusters)
    }
    
    private var filteredPhotosForMap: [Photo] {
        if !selectedDevices.isEmpty {
            return manager.photos.filter { photo in
                if let model = photo.cameraModel {
                    return selectedDevices.contains(model)
                }
                return false
            }
        } else {
            return manager.photos
        }
    }
    
    private var availableDevices: [String] {
        let models = manager.photos
            .filter { $0.latitude != nil && $0.longitude != nil }
            .compactMap(\.cameraModel)
        let uniqueModels = Array(Set(models))
        let counts = devicePhotoCounts
        return uniqueModels.sorted { model1, model2 in
            let count1 = counts[model1] ?? 0
            let count2 = counts[model2] ?? 0
            if count1 != count2 {
                return count1 > count2 // DESC order by count
            }
            return model1 < model2 // Alphabetical fallback
        }
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
                latitudeDelta: min(latDelta, 179.0),
                longitudeDelta: min(lonDelta, 360.0)
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
        userPreferredSpan = nextSpan
        centerTrigger = MKCoordinateRegion(center: current.center, span: nextSpan)
    }
    
    private func zoomOut() {
        let current = currentRegion
        let nextSpan = MKCoordinateSpan(
            latitudeDelta: min(179.0, current.span.latitudeDelta * 2.5),
            longitudeDelta: min(360.0, current.span.longitudeDelta * 2.5)
        )
        userPreferredSpan = nextSpan
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
        case .routes: return "point.topleft.down.to.point.bottomright.curvepath"
        }
    }
    
    private func deviceIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("iphone") {
            return "iphone"
        } else if lower.contains("gopro") || lower.contains("hero") {
            return "video.fill"
        } else if lower.contains("meta") || lower.contains("glasses") || lower.contains("ray-ban") {
            return "eyeglasses"
        } else if lower.contains("d5") || lower.contains("nikon") || lower.contains("canon") || lower.contains("sony") || lower.contains("fujifilm") || lower.contains("panasonic") || lower.contains("leica") || lower.contains("hasselblad") {
            return "camera.aperture"
        } else {
            return "camera.fill"
        }
    }
    
    // MARK: - Playback Helper Actions
    
    private func initializeTour() {
        previousVisualizationMode = visualizationMode
        withAnimation(.spring()) {
            visualizationMode = .routes
        }
        
        let count = sortedPhotos.count
        if count > 0 {
            // Default to 10 photos per second, clamped between 3s and 100s
            let calculated = Double(count) / 10.0
            playbackDuration = max(3.0, min(calculated, 100.0))
        } else {
            playbackDuration = 10.0
        }
        currentPhotoIndex = 1
        lastCenteredCoordinate = nil
        userPreferredSpan = currentRegion.span // lock initial zoom span preferred by user
        isPlaybackActive = true
        
        if autoPanEnabled, !sortedPhotos.isEmpty {
            autoPanToActivePhoto(at: 0, force: true)
        }
    }
    
    private func startAnimation() {
        guard !sortedPhotos.isEmpty else { return }
        
        if currentPhotoIndex >= sortedPhotos.count {
            currentPhotoIndex = 1
            lastCenteredCoordinate = nil
        }
        
        currentPhotoIndexDouble = Double(currentPhotoIndex)
        isPlaybackPlaying = true
        
        let totalPhotos = sortedPhotos.count
        let fps: Double = 30.0
        
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { timer in
            // Dynamically calculate the fractional index step based on current playbackDuration
            let step = (Double(totalPhotos) / self.playbackDuration) / fps
            self.currentPhotoIndexDouble = min(Double(totalPhotos), self.currentPhotoIndexDouble + step)
            
            let newIndex = min(totalPhotos, max(1, Int(self.currentPhotoIndexDouble)))
            
            if newIndex != self.currentPhotoIndex {
                self.currentPhotoIndex = newIndex
                if self.autoPanEnabled {
                    self.autoPanToActivePhoto(at: newIndex - 1)
                }
            }
            
            if self.currentPhotoIndexDouble >= Double(totalPhotos) {
                self.stopAnimation(finished: true)
            }
        }
    }
    
    private func pauseAnimation() {
        isPlaybackPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func stopAnimation(finished: Bool = false) {
        isPlaybackPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        if !finished {
            currentPhotoIndex = 1
            currentPhotoIndexDouble = 1.0
            lastCenteredCoordinate = nil
        }
    }
    
    private func closeTour() {
        stopAnimation()
        isPlaybackActive = false
        if let prev = previousVisualizationMode {
            withAnimation(.spring()) {
                visualizationMode = prev
            }
        }
    }
    
    private func autoPanToActivePhoto(at index: Int, force: Bool = false) {
        guard index >= 0 && index < sortedPhotos.count else { return }
        let photo = sortedPhotos[index]
        guard let lat = photo.latitude, let lon = photo.longitude else { return }
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        let shouldCenter: Bool
        if force {
            shouldCenter = true
        } else if let last = lastCenteredCoordinate {
            let latDiff = abs(last.latitude - coord.latitude)
            let lonDiff = abs(last.longitude - coord.longitude)
            shouldCenter = latDiff > 0.04 || lonDiff > 0.04
        } else {
            shouldCenter = true
        }
        
        if shouldCenter {
            lastCenteredCoordinate = coord
            let region = MKCoordinateRegion(
                center: coord,
                span: userPreferredSpan
            )
            centerTrigger = region
        }
    }
    
    private func formattedDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Playback Card Subview
    private var playbackCardView: some View {
        GlassCard(cornerRadius: 16, shadowRadius: 12) {
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 10))
                            Text("\(min(currentPhotoIndex, sortedPhotos.count)) / \(sortedPhotos.count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.emerald.opacity(0.15))
                        .cornerRadius(6)
                        .foregroundColor(.emerald)
                        
                        Text("(\(geotaggedPhotosCount) mapped • \(nonGeotaggedPhotosCount) unmapped)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    if !sortedPhotos.isEmpty {
                        let activePhoto = sortedPhotos[min(currentPhotoIndex - 1, sortedPhotos.count - 1)]
                        let firstPhoto = sortedPhotos.first!
                        let lastPhoto = sortedPhotos.last!
                        VStack(alignment: .leading, spacing: 3) {
                            Text(formattedDate(activePhoto.dateAdded))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 3)
                                
                                Capsule()
                                    .fill(Color.emerald)
                                    .frame(width: 140 * CGFloat(progressPercentage), height: 3)
                            }
                            .frame(width: 140, height: 3)
                            
                            HStack(spacing: 0) {
                                Text(formattedDate(firstPhoto.dateAdded))
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formattedDate(lastPhoto.dateAdded))
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 140)
                        }
                    } else {
                        Text("No photos to play")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            autoPanEnabled.toggle()
                        }
                    }) {
                        Image(systemName: autoPanEnabled ? "location.circle.fill" : "location.circle")
                            .font(.system(size: 14))
                            .foregroundColor(autoPanEnabled ? .emerald : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Auto-pan map to active photo location")
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            closeTour()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                
                Divider().background(Color.white.opacity(0.06))
                
                HStack(spacing: 12) {
                    Button(action: {
                        if isPlaybackPlaying {
                            pauseAnimation()
                        } else {
                            startAnimation()
                        }
                    }) {
                        Image(systemName: isPlaybackPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.emerald.opacity(0.85))
                            .clipShape(Circle())
                            .shadow(color: .emerald.opacity(0.3), radius: 3)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        stopAnimation()
                    }) {
                        Image(systemName: "backward.end.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    if !sortedPhotos.isEmpty {
                        Slider(
                            value: Binding(
                                get: { Double(currentPhotoIndex) },
                                set: { newValue in
                                    pauseAnimation()
                                    currentPhotoIndex = max(1, min(Int(newValue), sortedPhotos.count))
                                    if autoPanEnabled {
                                        autoPanToActivePhoto(at: currentPhotoIndex - 1)
                                    }
                                }
                            ),
                            in: 1...Double(sortedPhotos.count),
                            step: 1
                        )
                        .accentColor(.emerald)
                    } else {
                        Slider(value: .constant(0), in: 0...1)
                            .disabled(true)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("Duration")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Slider(
                        value: Binding(
                            get: { playbackDuration },
                            set: { newValue in
                                playbackDuration = newValue
                                if isPlaybackPlaying {
                                    startAnimation()
                                }
                            }
                        ),
                        in: 2.0...100.0
                    )
                    .accentColor(.cyan)
                    
                    Text("\(Int(playbackDuration))s")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .frame(width: 28, alignment: .trailing)
                    
                    Divider()
                        .frame(height: 12)
                        .background(Color.white.opacity(0.08))
                    
                    let speed = sortedPhotos.isEmpty ? 0 : Int(round(Double(sortedPhotos.count) / playbackDuration))
                    Text("\(speed) photos/s")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(14)
        }
        .frame(width: 440)
        .glassCardHoverEffect(cornerRadius: 16)
    }
}
