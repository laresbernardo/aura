import SwiftUI
import Photos

// MARK: - Reusable Photo Thumbnail View
struct PhotoThumbnailView: View {
    let photoId: String
    let sourceMode: PhotosLibraryManager.SourceMode
    var size: CGSize = CGSize(width: 32, height: 24)
    
    @State private var image: NSImage? = nil
    
    var body: some View {
        Group {
            if sourceMode == .demo {
                // Procedural high-fidelity neon gradient for demo mode
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: NSColor.systemTeal).opacity(0.85),
                                Color(nsColor: NSColor.systemPurple).opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: size.height * 0.45))
                            .foregroundColor(.white.opacity(0.95))
                    )
            } else {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.4)
                        )
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: photoId) {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard sourceMode == .direct else { return }
        
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [photoId], options: nil)
        guard let asset = result.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { img, _ in
            if let img = img {
                DispatchQueue.main.async {
                    self.image = img
                }
            }
        }
    }
}

// MARK: - Reusable Photo Preview Popover View
struct PhotoPreviewPopoverView: View {
    let photo: Photo
    let sourceMode: PhotosLibraryManager.SourceMode
    
    @State private var previewImage: NSImage? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if sourceMode == .demo {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(nsColor: NSColor.systemTeal),
                                    Color(nsColor: NSColor.systemPurple)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo.artframe")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("Offline Demo Preview")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        )
                } else {
                    if let img = previewImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.04))
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
            }
            .frame(width: 220, height: 150)
            .cornerRadius(6)
            .clipped()
            
            VStack(alignment: .leading, spacing: 3) {
                Text(photo.filename)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    Text("\(photo.width) × \(photo.height)")
                    Spacer()
                    if let camera = photo.cameraModel {
                        Text(camera)
                    }
                }
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                
                Text(formatDate(photo.dateAdded))
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                
                if sourceMode == .direct {
                    Divider().background(Color.white.opacity(0.1))
                        .padding(.vertical, 2)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.emerald)
                        Text("Click ↗ to open HD in Photos app")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.emerald)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(8)
        .frame(width: 236)
        .onAppear {
            loadPreview()
        }
    }
    
    private func loadPreview() {
        guard sourceMode == .direct else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [photo.id], options: nil)
        guard let asset = result.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 440, height: 300), // Retina resolution
            contentMode: .aspectFill,
            options: options
        ) { img, _ in
            if let img = img {
                DispatchQueue.main.async {
                    self.previewImage = img
                }
            }
        }
    }
    
    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Reusable Hover Preview Modifier
struct PhotoPreviewHoverModifier: ViewModifier {
    let photo: Photo
    let sourceMode: PhotosLibraryManager.SourceMode
    
    @State private var isHovering = false
    @State private var showPopover = false
    
    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if self.isHovering {
                            self.showPopover = true
                        }
                    }
                } else {
                    self.showPopover = false
                }
            }
            .popover(isPresented: $showPopover, arrowEdge: .trailing) {
                PhotoPreviewPopoverView(photo: photo, sourceMode: sourceMode)
            }
    }
}

extension View {
    func photoPreviewHover(photo: Photo, sourceMode: PhotosLibraryManager.SourceMode) -> some View {
        self.modifier(PhotoPreviewHoverModifier(photo: photo, sourceMode: sourceMode))
    }
}
