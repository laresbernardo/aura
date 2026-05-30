import SwiftUI

struct PhotosAuraView: View {
    @ObservedObject var manager: PhotosLibraryManager
    @State private var isProfileCardHovered = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Photography Aura Profile")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("A premium behavioral profile that classifies your photography style based on travel geographics, gear usage, and magic hour ratios.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                let profile = manager.photographyPersona
                
                // MARK: - Premium Glowing Persona Card
                GlassCard(cornerRadius: 24, shadowRadius: 18) {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("YOUR PHOTOGRAPHY AURA IS:")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.white.opacity(0.6))
                                    .textCase(.uppercase)
                                
                                Text(profile.name)
                                    .font(.system(size: 34, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 4)
                                
                                Text(profile.subtitle)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(LinearGradient(colors: profile.gradientColors, startPoint: .leading, endPoint: .trailing))
                            }
                            
                            Spacer()
                            
                            // Glowing Sphere Icon matching the aura profile
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: profile.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 80, height: 80)
                                    .blur(radius: 8)
                                    .opacity(isProfileCardHovered ? 0.95 : 0.75)
                                    .scaleEffect(isProfileCardHovered ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: isProfileCardHovered)
                                
                                Circle()
                                    .fill(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .white.opacity(0.4), radius: 5)
                            }
                        }
                        
                        Text(profile.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(6)
                        
                        Divider().background(Color.white.opacity(0.08))
                        
                        Text("This classification analyzes your geographical captures, camera hardware metadata, and crop sizes dynamically as your library syncs.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(32)
                }
                .glassCardHoverEffect(cornerRadius: 24)
                .onHover { isProfileCardHovered = $0 }
                
                // MARK: - Creative Parameters List
                Text("Your Aura Parameters")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                GlassCard(cornerRadius: 18, shadowRadius: 12) {
                    VStack(spacing: 24) {
                        PhotosParameterMeterRow(
                            title: "Travel Breadth",
                            value: profile.nostalgiaIndex, // Reusing field
                            lowLabel: "Local Memory Keeper",
                            highLabel: "Global Jetsetter",
                            icon: "globe.americas.fill",
                            color: .emerald
                        )
                        
                        // Camera Gear Index
                        PhotosParameterMeterRow(
                            title: "Camera Gear Index",
                            value: profile.varietyScore, // Reusing field
                            lowLabel: "Smartphone Convenience",
                            highLabel: "Fine Art Mirrorless",
                            icon: "camera.aperture",
                            color: .cyan
                        )
                        
                        // Golden Hour Ratio
                        PhotosParameterMeterRow(
                            title: "Golden Hour Ratio",
                            value: profile.focusScore, // Reusing field
                            lowLabel: "Midday Exposures",
                            highLabel: "Magic Hour Chaser",
                            icon: "sunset.fill",
                            color: .orange
                        )
                        
                        // Composition Focus
                        PhotosParameterMeterRow(
                            title: "Cinematic Horizons",
                            value: profile.loyaltyScore, // Reusing field
                            lowLabel: "Standard Crops",
                            highLabel: "Panoramic Perspectives",
                            icon: "aspectratio.fill",
                            color: .purple
                        )
                    }
                    .padding(28)
                }
                .glassCardHoverEffect(cornerRadius: 18)
            }
            .padding(4)
        }
    }
}

struct PhotosParameterMeterRow: View {
    let title: String
    let value: Double
    let lowLabel: String
    let highLabel: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Info
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14))
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Spacer()
                
                Text(String(format: "%.1f%%", value))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            // Progress Bar Slider
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(12, geo.size.width * CGFloat(value / 100.0)), height: 8)
                        .shadow(color: color.opacity(0.35), radius: 4)
                }
            }
            .frame(height: 8)
            
            // Range Labels
            HStack {
                Text(lowLabel)
                Spacer()
                Text(highLabel)
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
    }
}
