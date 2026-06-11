import SwiftUI

// MARK: - App Navigation Enums
enum AppMode: String, CaseIterable, Identifiable {
    case music = "Music"
    case photos = "Photos"
    var id: String { rawValue }
}

enum MusicTab: String, CaseIterable {
    case overview = "Overview"
    case habits = "Listening Habits"
    case artists = "Artist Hall"
    case persona = "Aura Profile"
    case temporal = "Sonic Rhythms"
    case timeMachine = "Time Machine"
}

enum PhotosTab: String, CaseIterable {
    case photosOverview = "Overview"
    case photosBehavior = "Behavior"
    case photosPlaces = "Places"
    case photosHeatmap = "Interactive Map"
    case photosAura = "Photo Aura"
}

struct MainView: View {
    @StateObject var manager = MusicLibraryManager()
    @StateObject var photosManager = PhotosLibraryManager()
    
    @State private var appMode: AppMode = .music
    @State private var currentMusicTab: MusicTab = .overview
    @State private var currentPhotosTab: PhotosTab = .photosOverview
    @State private var isSyncButtonHovered = false
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Premium Sidebar Layout
            VStack(alignment: .leading, spacing: 18) {
                // App Brand / Logo Section
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: appMode == .music ? [.purple, .pink] : [.emerald, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 32, height: 32)
                            .shadow(color: (appMode == .music ? Color.purple : Color.emerald).opacity(0.35), radius: 4)
                        
                        Image(systemName: appMode == .music ? "music.note" : "camera.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AURA")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        Text(appMode == .music ? "Music Analytics" : "Photo Analytics")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // MARK: - Mode Switcher (Music vs Photos Toggle)
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            appMode = .music
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note")
                                .font(.system(size: 11))
                            Text("Music")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(appMode == .music ? Color.purple.opacity(0.8) : Color.clear)
                        )
                        .foregroundColor(appMode == .music ? .white : .secondary)
                        .shadow(color: appMode == .music ? .purple.opacity(0.25) : .clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            appMode = .photos
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 11))
                            Text("Photos")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(appMode == .photos ? Color.emerald.opacity(0.8) : Color.clear)
                        )
                        .foregroundColor(appMode == .photos ? .white : .secondary)
                        .shadow(color: appMode == .photos ? .emerald.opacity(0.25) : .clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(3)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                
                // Navigation Links (Swapped dynamically based on Active Mode)
                VStack(spacing: 5) {
                    if appMode == .music {
                        ForEach(MusicTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    currentMusicTab = tab
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: musicTabIcon(for: tab))
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(width: 18)
                                        .foregroundColor(currentMusicTab == tab ? .white : .secondary)
                                    
                                    Text(tab.rawValue)
                                        .font(.body)
                                        .fontWeight(currentMusicTab == tab ? .semibold : .regular)
                                        .foregroundColor(currentMusicTab == tab ? .white : .secondary)
                                    
                                    Spacer()
                                    
                                    if currentMusicTab == tab {
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 5, height: 5)
                                            .shadow(color: .purple, radius: 3)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(currentMusicTab == tab ? Color.white.opacity(0.08) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        ForEach(PhotosTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    currentPhotosTab = tab
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: photosTabIcon(for: tab))
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(width: 18)
                                        .foregroundColor(currentPhotosTab == tab ? .white : .secondary)
                                    
                                    Text(tab.rawValue)
                                        .font(.body)
                                        .fontWeight(currentPhotosTab == tab ? .semibold : .regular)
                                        .foregroundColor(currentPhotosTab == tab ? .white : .secondary)
                                    
                                    Spacer()
                                    
                                    if currentPhotosTab == tab {
                                        Circle()
                                            .fill(Color.emerald)
                                            .frame(width: 5, height: 5)
                                            .shadow(color: .emerald, radius: 3)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(currentPhotosTab == tab ? Color.white.opacity(0.08) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                // MARK: - Footer Connection Config
                VStack(spacing: 12) {
                    Divider().background(Color.white.opacity(0.08))
                    
                    if appMode == .music {
                        // Music Footer Configuration
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Library Source")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(manager.sourceModeDescription)
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Circle()
                                    .fill(manager.sourceModeColor)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: manager.sourceModeColor, radius: 4)
                            }
                            
                            Picker("", selection: Binding(
                                get: { manager.sourceMode },
                                set: { manager.changeSourceMode(to: $0) }
                            )) {
                                Text("Demo").tag(MusicLibraryManager.SourceMode.demo)
                                Text("XML").tag(MusicLibraryManager.SourceMode.xml)
                                Text("Direct").tag(MusicLibraryManager.SourceMode.direct)
                            }
                            .pickerStyle(.segmented)
                            .scaleEffect(0.9)
                            .padding(.horizontal, -4)
                        }
                        .padding(.horizontal, 12)
                        
                        if manager.sourceMode != .demo {
                            VStack(spacing: 6) {
                                Button(action: {
                                    Task {
                                        if manager.sourceMode == .xml {
                                            await manager.fetchLiveLibrary()
                                        } else {
                                            await manager.fetchDirectLibrary()
                                        }
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        if manager.isLoading {
                                            ProgressView().controlSize(.small).scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        Text(manager.isLoading ? "Syncing..." : "Sync Now")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(manager.isLoading)
                                
                                if manager.sourceMode == .xml {
                                    Button(action: {
                                        Task { await manager.selectXMLFileManually() }
                                    }) {
                                        Text("Change XML Source...")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 5)
                                            .background(Color.white.opacity(0.02))
                                            .cornerRadius(5)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    } else {
                        // Photos Footer Configuration
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Library Source")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(photosManager.sourceModeDescription)
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Circle()
                                    .fill(photosManager.sourceModeColor)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: photosManager.sourceModeColor, radius: 4)
                            }
                            
                            Picker("", selection: Binding(
                                get: { photosManager.sourceMode },
                                set: { photosManager.changeSourceMode(to: $0) }
                            )) {
                                Text("Demo").tag(PhotosLibraryManager.SourceMode.demo)
                                Text("Direct").tag(PhotosLibraryManager.SourceMode.direct)
                            }
                            .pickerStyle(.segmented)
                            .scaleEffect(0.9)
                            .padding(.horizontal, -4)
                        }
                        .padding(.horizontal, 12)
                        
                        if photosManager.sourceMode == .direct {
                            Button(action: {
                                Task { await photosManager.fetchDirectLibrary() }
                            }) {
                                HStack(spacing: 8) {
                                    if photosManager.isLoading {
                                        ProgressView().controlSize(.small).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    Text(photosManager.isLoading ? "Syncing..." : "Sync Now")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(photosManager.isLoading)
                            .padding(.horizontal, 12)
                        }
                    }
                    
                    // Application Version & Credits
                    VStack(spacing: 5) {
                        Text("Aura \(manager.appVersionString)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        Button(action: {
                            if let url = URL(string: "https://bervos.org") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 5) {
                                if let logoURL = Bundle.main.url(forResource: "BervosLogo", withExtension: "png"),
                                   let nsImage = NSImage(contentsOf: logoURL) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .colorMultiply(.white.opacity(0.6))
                                }
                                
                                Text("by BERVOS")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .padding(.bottom, 12)
            }
            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
            .frame(minWidth: 220)
        } detail: {
            // MARK: - Detail Panel Views
            ZStack {
                // Background Gradient shifting dynamically based on App Mode
                LinearGradient(
                    colors: appMode == .music ? [
                        Color(red: 11/255, green: 10/255, blue: 18/255),
                        Color(red: 18/255, green: 18/255, blue: 30/255)
                    ] : [
                        Color(red: 8/255, green: 18/255, blue: 14/255),
                        Color(red: 10/255, green: 15/255, blue: 18/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Dynamic Detail Switching
                VStack {
                    if appMode == .music {
                        // MUSIC MODE DETAIL VIEWPORT
                        if !manager.isDemoMode && manager.isLoading {
                            ProgressView("Reading Music library…")
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        } else if !manager.isDemoMode, let errorMsg = manager.syncError {
                            XMLErrorFallbackView(message: errorMsg, manager: manager)
                                .transition(.opacity)
                        } else {
                            VStack(spacing: 0) {
                                // Music Date Filter Bar (Dynamic Horizontal Year Scrolling Bar)
                                HStack(spacing: 12) {
                                    Text("Time Range:")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.leading, 28)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            // All Time Capsule
                                            Button(action: {
                                                manager.currentFilter = .allTime
                                                manager.applyFilter()
                                            }) {
                                                Text("All Time")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 5)
                                                    .background(manager.currentFilter == .allTime ? Color.purple.opacity(0.18) : Color.white.opacity(0.04))
                                                    .foregroundColor(manager.currentFilter == .allTime ? .purple : .secondary)
                                                    .cornerRadius(10)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(manager.currentFilter == .allTime ? Color.purple.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                            
                                            // Dynamic Year Capsules
                                            ForEach(manager.availableYears, id: \.self) { year in
                                                let isSelected = manager.currentFilter == .specificYear(year)
                                                Button(action: {
                                                    manager.currentFilter = .specificYear(year)
                                                    manager.applyFilter()
                                                }) {
                                                    Text(String(year))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 5)
                                                        .background(isSelected ? Color.purple.opacity(0.18) : Color.white.opacity(0.04))
                                                        .foregroundColor(isSelected ? .purple : .secondary)
                                                        .cornerRadius(10)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .stroke(isSelected ? Color.purple.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            
                                            // Custom Range Capsule
                                            Button(action: {
                                                manager.currentFilter = .customRange
                                                manager.applyFilter()
                                            }) {
                                                Text("Custom")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 5)
                                                    .background(manager.currentFilter == .customRange ? Color.purple.opacity(0.18) : Color.white.opacity(0.04))
                                                    .foregroundColor(manager.currentFilter == .customRange ? .purple : .secondary)
                                                    .cornerRadius(10)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(manager.currentFilter == .customRange ? Color.purple.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    Spacer()
                                    
                                    if manager.currentFilter == .customRange {
                                        NiceDateRangePickerButton(
                                            startDate: Binding(
                                                get: { manager.customStartDate },
                                                set: { manager.customStartDate = $0 }
                                            ),
                                            endDate: Binding(
                                                get: { manager.customEndDate },
                                                set: { manager.customEndDate = $0 }
                                            ),
                                            tintColor: .purple,
                                            onDatesChanged: { manager.applyFilter() }
                                        )
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 28)
                                .padding(.top, 20)
                                .padding(.bottom, 6)
                                
                                Group {
                                    switch currentMusicTab {
                                    case .overview:
                                        OverviewDashboardView(manager: manager)
                                    case .habits:
                                        ListeningHabitsView(manager: manager)
                                    case .artists:
                                        ArtistHallView(manager: manager)
                                    case .persona:
                                        AuraProfileView(manager: manager)
                                    case .temporal:
                                        TemporalRhythmsView(manager: manager)
                                    case .timeMachine:
                                        TimeMachineView(manager: manager)
                                    }
                                }
                                .padding(.horizontal, 28)
                                .padding(.bottom, 28)
                                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                            }
                        }
                    } else {
                        // PHOTOS MODE DETAIL VIEWPORT
                        if photosManager.sourceMode == .direct && photosManager.isLoading {
                            PhotosSyncLoadingView(manager: photosManager)
                                .transition(.opacity)
                        } else if photosManager.sourceMode == .direct, let errorMsg = photosManager.syncError {
                            PhotosErrorFallbackView(message: errorMsg, manager: photosManager)
                                .transition(.opacity)
                        } else {
                            VStack(spacing: 0) {
                                // Photos Date Filter Bar (Dynamic Horizontal Year Scrolling Bar)
                                HStack(spacing: 12) {
                                    Text("Time Range:")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.leading, 28)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            // All Time Capsule
                                            Button(action: {
                                                photosManager.currentFilter = .allTime
                                                photosManager.applyFilter()
                                            }) {
                                                Text("All Time")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 5)
                                                    .background(photosManager.currentFilter == .allTime ? Color.emerald.opacity(0.18) : Color.white.opacity(0.04))
                                                    .foregroundColor(photosManager.currentFilter == .allTime ? .emerald : .secondary)
                                                    .cornerRadius(10)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(photosManager.currentFilter == .allTime ? Color.emerald.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                            
                                            // Dynamic Year Capsules
                                            ForEach(photosManager.availableYears, id: \.self) { year in
                                                let isSelected = photosManager.currentFilter == .specificYear(year)
                                                Button(action: {
                                                    photosManager.currentFilter = .specificYear(year)
                                                    photosManager.applyFilter()
                                                }) {
                                                    Text(String(year))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 5)
                                                        .background(isSelected ? Color.emerald.opacity(0.18) : Color.white.opacity(0.04))
                                                        .foregroundColor(isSelected ? .emerald : .secondary)
                                                        .cornerRadius(10)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10)
                                                                .stroke(isSelected ? Color.emerald.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            
                                            // Custom Range Capsule
                                            Button(action: {
                                                photosManager.currentFilter = .customRange
                                                photosManager.applyFilter()
                                            }) {
                                                Text("Custom")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 5)
                                                    .background(photosManager.currentFilter == .customRange ? Color.emerald.opacity(0.18) : Color.white.opacity(0.04))
                                                    .foregroundColor(photosManager.currentFilter == .customRange ? .emerald : .secondary)
                                                    .cornerRadius(10)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .stroke(photosManager.currentFilter == .customRange ? Color.emerald.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    Spacer()
                                    
                                    if photosManager.currentFilter == .customRange {
                                        NiceDateRangePickerButton(
                                            startDate: Binding(
                                                get: { photosManager.customStartDate },
                                                set: { photosManager.customStartDate = $0 }
                                            ),
                                            endDate: Binding(
                                                get: { photosManager.customEndDate },
                                                set: { photosManager.customEndDate = $0 }
                                            ),
                                            tintColor: .emerald,
                                            onDatesChanged: { photosManager.applyFilter() }
                                        )
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 28)
                                .padding(.top, 20)
                                .padding(.bottom, 6)
                                
                                Group {
                                    switch currentPhotosTab {
                                    case .photosOverview:
                                        PhotosOverviewView(manager: photosManager)
                                    case .photosBehavior:
                                        PhotosBehaviorView(manager: photosManager)
                                    case .photosPlaces:
                                        PhotosPlacesView(manager: photosManager)
                                    case .photosHeatmap:
                                        PhotosHeatmapView(manager: photosManager)
                                    case .photosAura:
                                        PhotosAuraView(manager: photosManager)
                                    }
                                }
                                .padding(.horizontal, 28)
                                .padding(.bottom, 28)
                                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 980, minHeight: 650)
    }
    
    // Tab Icons Map for Music
    private func musicTabIcon(for tab: MusicTab) -> String {
        switch tab {
        case .overview: return "chart.bar.doc.horizontal.fill"
        case .habits: return "waveform.path.ecg.rectangle"
        case .artists: return "person.3.sequence.fill"
        case .persona: return "sparkles.rectangle.stack.fill"
        case .temporal: return "clock.badge.checkmark"
        case .timeMachine: return "clock.arrow.2.circlepath"
        }
    }
    
    // Tab Icons Map for Photos
    private func photosTabIcon(for tab: PhotosTab) -> String {
        switch tab {
        case .photosOverview: return "photo.on.rectangle.angled"
        case .photosBehavior: return "clock.arrow.2.circlepath"
        case .photosPlaces: return "mappin.and.ellipse"
        case .photosHeatmap: return "map.fill"
        case .photosAura: return "sparkles"
        }
    }
}

// MARK: - Photos Error Fallback View
struct PhotosErrorFallbackView: View {
    let message: String
    @ObservedObject var manager: PhotosLibraryManager
    @State private var isHovered = false

    var body: some View {
        GlassCard(cornerRadius: 20, shadowRadius: 16) {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.emerald.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.system(size: 28))
                        .foregroundColor(.emerald)
                }

                VStack(spacing: 8) {
                    Text("Could Not Connect to Photos")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(message)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }
                .padding(.horizontal, 16)

                Divider().background(Color.white.opacity(0.08))

                // One-time setup instruction
                VStack(alignment: .leading, spacing: 12) {
                    Text("Establishing Connection:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .textCase(.uppercase)

                    HStack(alignment: .top, spacing: 10) {
                        Text("1.")
                            .font(.caption).fontWeight(.bold).foregroundColor(.emerald)
                        Text("Click the **Launch Photos** button below to ensure the application is open.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 10) {
                        Text("2.")
                            .font(.caption).fontWeight(.bold).foregroundColor(.emerald)
                        Text("Click **Retry Connection**. When prompted by macOS, select **OK** to authorize control of Apple Photos.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                HStack(spacing: 16) {
                    Button(action: {
                        Task { await manager.fetchDirectLibrary() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .bold))
                            Text("Retry Connection")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isHovered ? Color.emerald.opacity(0.95) : Color.emerald.opacity(0.8))
                                .shadow(color: .emerald.opacity(0.3), radius: 8, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered = $0 }
                    
                    Button(action: {
                        manager.launchPhotosApp()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right.app")
                                .font(.system(size: 12, weight: .bold))
                            Text("Launch Photos")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
        .frame(width: 520)
    }
}

// MARK: - Fallback: XML Library Error
struct XMLErrorFallbackView: View {
    let message: String
    @ObservedObject var manager: MusicLibraryManager
    @State private var isHovered = false

    var body: some View {
        GlassCard(cornerRadius: 20, shadowRadius: 16) {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                }

                VStack(spacing: 8) {
                    Text("Could Not Read Music Library")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text(message)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }
                .padding(.horizontal, 16)

                Divider().background(Color.white.opacity(0.08))

                // One-time setup instruction
                VStack(alignment: .leading, spacing: 12) {
                    Text("One-time setup (30 seconds):")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .textCase(.uppercase)

                    stepRow(number: "1", text: "Open **Music.app**.")
                    stepRow(number: "2", text: "In the menu bar: **File → Library → Export Library…**")
                    stepRow(number: "3", text: "Save the file anywhere (the name doesn't matter).")
                    stepRow(number: "4", text: "Click **Retry** — Aura will find and read it automatically.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)

                HStack(spacing: 16) {
                    Button(action: {
                        Task { await manager.fetchLiveLibrary() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .bold))
                            Text("Retry")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isHovered ? Color.orange.opacity(0.95) : Color.orange.opacity(0.8))
                                .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered = $0 }
                    
                    Button(action: {
                        Task { await manager.selectXMLFileManually() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Select XML Manually...")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(40)
        }
        .frame(width: 520)
    }

    @ViewBuilder
    private func stepRow(number: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number + ".")
                .font(.caption).fontWeight(.bold).foregroundColor(.orange)
                .frame(width: 14, alignment: .leading)
            Text(text)
                .font(.caption).foregroundColor(.secondary).lineSpacing(3)
        }
    }
}

// MARK: - Photos Sync Loading View
struct PhotosSyncLoadingView: View {
    @ObservedObject var manager: PhotosLibraryManager
    @State private var rotationAngle: Double = 0.0
    @State private var pulseScale: CGFloat = 0.95
    @State private var pulseOpacity: Double = 0.6
    
    var body: some View {
        GlassCard(cornerRadius: 24, shadowRadius: 20) {
            VStack(spacing: 28) {
                // Animated Spinner/Aperture Ring
                ZStack {
                    // Rotating outer gradient ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.emerald, .teal, .cyan, .emerald],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: rotationAngle))
                        .shadow(color: Color.emerald.opacity(0.3), radius: 6)
                    
                    // Outer glow static ring
                    Circle()
                        .stroke(Color.white.opacity(0.04), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    // Pulsating center brand logo icon
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.emerald, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.emerald.opacity(0.4), radius: 5)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                }
                .frame(width: 100, height: 100)
                
                // Status text section
                VStack(spacing: 8) {
                    Text("Syncing Photo Library")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(manager.syncStatus.isEmpty ? "Preparing assets..." : manager.syncStatus)
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(height: 40)
                        .padding(.horizontal, 16)
                }
                
                // Linear Progress Bar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.emerald, .teal, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(manager.syncProgressFraction), height: 6)
                                .shadow(color: Color.emerald.opacity(0.4), radius: 4)
                                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: manager.syncProgressFraction)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Spacer()
                        Text(String(format: "%.0f%%", manager.syncProgressFraction * 100))
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.emerald)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .frame(width: 380)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                rotationAngle = 360.0
            }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
                pulseOpacity = 1.0
            }
        }
    }
}


// MARK: - Premium Customized Date Range Picker Trigger Button
struct NiceDateRangePickerButton: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let tintColor: Color
    let onDatesChanged: () -> Void
    @State private var isPopoverPresented = false
    
    @State private var startDateText = ""
    @State private var endDateText = ""
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func parseDate(_ string: String) -> Date? {
        let clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM-dd-yyyy", "MM/dd/yyyy"]
        let formatter = DateFormatter()
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: clean) {
                return date
            }
        }
        return nil
    }
    
    enum PresetRange: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case last30Days = "Last 30 Days"
        case currentYear = "Current Year"
        case lastYear = "Last Year"
        case last5Years = "Last 5 Years"
        case last10Years = "Last 10 Years"
        
        var id: String { rawValue }
    }
    
    private func presetStartDate(for preset: PresetRange, now: Date) -> Date {
        let calendar = Calendar.current
        switch preset {
        case .allTime:
            return calendar.date(from: DateComponents(year: 1950, month: 1, day: 1)) ?? now
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case .currentYear:
            let currentYear = calendar.component(.year, from: now)
            return calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? now
        case .lastYear:
            let lastYear = calendar.component(.year, from: now) - 1
            return calendar.date(from: DateComponents(year: lastYear, month: 1, day: 1)) ?? now
        case .last5Years:
            return calendar.date(byAdding: .year, value: -5, to: now) ?? now
        case .last10Years:
            return calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }
    }
    
    private func presetEndDate(for preset: PresetRange, now: Date) -> Date {
        let calendar = Calendar.current
        switch preset {
        case .allTime, .last30Days, .currentYear, .last5Years, .last10Years:
            return now
        case .lastYear:
            let lastYear = calendar.component(.year, from: now) - 1
            return calendar.date(from: DateComponents(year: lastYear, month: 12, day: 31, hour: 23, minute: 59, second: 59)) ?? now
        }
    }
    
    private func isPresetActive(_ preset: PresetRange) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfPresetStart = calendar.startOfDay(for: presetStartDate(for: preset, now: now))
        let startOfPresetEnd = calendar.startOfDay(for: presetEndDate(for: preset, now: now))
        
        let currentStart = calendar.startOfDay(for: startDate)
        let currentEnd = calendar.startOfDay(for: endDate)
        
        return abs(currentStart.timeIntervalSince(startOfPresetStart)) < 3600 &&
               abs(currentEnd.timeIntervalSince(startOfPresetEnd)) < 3600
    }
    
    private func applyPreset(_ preset: PresetRange) {
        let now = Date()
        startDate = presetStartDate(for: preset, now: now)
        endDate = presetEndDate(for: preset, now: now)
        onDatesChanged()
    }
    
    private var startYear: Int {
        Calendar.current.component(.year, from: startDate)
    }

    private var startMonth: Int {
        Calendar.current.component(.month, from: startDate)
    }

    private var endYear: Int {
        Calendar.current.component(.year, from: endDate)
    }

    private var endMonth: Int {
        Calendar.current.component(.month, from: endDate)
    }

    private var startYearsList: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let maxYear = min(endYear, currentYear)
        return Array(1940...maxYear).reversed()
    }

    private var startMonthsList: [(String, Int)] {
        let allMonths = [
            ("Jan", 1), ("Feb", 2), ("Mar", 3), ("Apr", 4), ("May", 5), ("Jun", 6),
            ("Jul", 7), ("Aug", 8), ("Sep", 9), ("Oct", 10), ("Nov", 11), ("Dec", 12)
        ]
        if startYear >= endYear {
            return allMonths.filter { $0.1 <= endMonth }
        }
        return allMonths
    }

    private var endYearsList: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let minYear = startYear
        return Array(minYear...currentYear).reversed()
    }

    private var endMonthsList: [(String, Int)] {
        let allMonths = [
            ("Jan", 1), ("Feb", 2), ("Mar", 3), ("Apr", 4), ("May", 5), ("Jun", 6),
            ("Jul", 7), ("Aug", 8), ("Sep", 9), ("Oct", 10), ("Nov", 11), ("Dec", 12)
        ]
        if endYear <= startYear {
            return allMonths.filter { $0.1 >= startMonth }
        }
        return allMonths
    }
    
    private func monthName(for month: Int) -> String {
        let allMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard month >= 1 && month <= 12 else { return "Month" }
        return allMonths[month - 1]
    }
    
    private func jumpToYear(_ year: Int, isStart: Bool) {
        let calendar = Calendar.current
        var date = isStart ? startDate : endDate
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.year = year
        
        if let newDate = calendar.date(from: components) {
            date = newDate
        } else {
            components.day = 1
            if let newDate = calendar.date(from: components) {
                date = newDate
            }
        }
        
        if isStart {
            if date > endDate {
                endDate = date
            }
            startDate = date
        } else {
            if date < startDate {
                startDate = date
            }
            endDate = date
        }
        onDatesChanged()
    }

    private func jumpToMonth(_ month: Int, isStart: Bool) {
        let calendar = Calendar.current
        var date = isStart ? startDate : endDate
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.month = month
        
        if let newDate = calendar.date(from: components) {
            date = newDate
        } else {
            components.day = 1
            if let newDate = calendar.date(from: components) {
                date = newDate
            }
        }
        
        if isStart {
            if date > endDate {
                endDate = date
            }
            startDate = date
        } else {
            if date < startDate {
                startDate = date
            }
            endDate = date
        }
        onDatesChanged()
    }
    
    var body: some View {
        Button(action: { isPopoverPresented.toggle() }) {
            HStack(spacing: 6) {
                Text(formattedDate(startDate))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(tintColor)
                
                Text("to")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(formattedDate(endDate))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.95))
                
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(tintColor)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isPopoverPresented ? tintColor.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            let useVerticalLayout = (NSApp.keyWindow?.frame.width ?? 800) < 700
            
            VStack(spacing: 12) {
                Text("Select Date Range")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.top, 10)
                
                if useVerticalLayout {
                    VStack(spacing: 12) {
                        // Vertical presets scroll view
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(PresetRange.allCases) { preset in
                                    let active = isPresetActive(preset)
                                    Button(action: { applyPreset(preset) }) {
                                        Text(preset.rawValue)
                                            .font(.system(size: 10, weight: active ? .bold : .medium))
                                            .foregroundColor(active ? tintColor : .white.opacity(0.7))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(active ? tintColor.opacity(0.12) : Color.white.opacity(0.04))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        // Text Inputs Row
                        HStack(spacing: 8) {
                            TextField("Start Date", text: $startDateText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(startDateText.isEmpty || parseDate(startDateText) != nil ? Color.white.opacity(0.08) : Color.orange.opacity(0.6), lineWidth: 1)
                                )
                                .frame(width: 95)
                                .onChange(of: startDateText) { newValue in
                                    if let parsed = parseDate(newValue) {
                                        if parsed > endDate {
                                            endDate = parsed
                                        }
                                        startDate = parsed
                                        onDatesChanged()
                                    }
                                }
                            
                            Text("to")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            TextField("End Date", text: $endDateText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(endDateText.isEmpty || parseDate(endDateText) != nil ? Color.white.opacity(0.08) : Color.orange.opacity(0.6), lineWidth: 1)
                                )
                                .frame(width: 95)
                                .onChange(of: endDateText) { newValue in
                                    if let parsed = parseDate(newValue) {
                                        if parsed < startDate {
                                            startDate = parsed
                                        }
                                        endDate = parsed
                                        onDatesChanged()
                                    }
                                }
                        }
                        
                        Divider().background(Color.white.opacity(0.08))
                        
                        VStack(spacing: 8) {
                            // Start Date
                            VStack(spacing: 4) {
                                Text("Start Date")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { startDate },
                                        set: { newDate in
                                            startDate = newDate
                                            if startDate > endDate {
                                                endDate = startDate
                                            }
                                            onDatesChanged()
                                        }
                                    ),
                                    in: ...endDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .frame(width: 200, height: 160)
                            }
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            // End Date
                            VStack(spacing: 4) {
                                Text("End Date")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { endDate },
                                        set: { newDate in
                                            endDate = newDate
                                            if endDate < startDate {
                                                startDate = endDate
                                            }
                                            onDatesChanged()
                                        }
                                    ),
                                    in: startDate...,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .frame(width: 200, height: 160)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .frame(width: 230)
                } else {
                    HStack(spacing: 0) {
                        // Presets Column
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PRESETS")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                                .padding(.leading, 4)
                            
                            ForEach(PresetRange.allCases) { preset in
                                let active = isPresetActive(preset)
                                Button(action: { applyPreset(preset) }) {
                                    Text(preset.rawValue)
                                        .font(.system(size: 11, weight: active ? .semibold : .medium))
                                        .foregroundColor(active ? tintColor : .white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(active ? tintColor.opacity(0.12) : Color.clear)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .frame(width: 125)
                        .padding(.trailing, 8)
                        
                        VerticalDivider()
                        
                        // Calendars & Inputs Area
                        VStack(spacing: 12) {
                            // Text Inputs Row
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("START DATE")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    TextField("YYYY-MM-DD", text: $startDateText)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(startDateText.isEmpty || parseDate(startDateText) != nil ? Color.white.opacity(0.08) : Color.orange.opacity(0.6), lineWidth: 1)
                                        )
                                        .frame(width: 105)
                                        .onChange(of: startDateText) { newValue in
                                            if let parsed = parseDate(newValue) {
                                                if parsed > endDate {
                                                    endDate = parsed
                                                }
                                                startDate = parsed
                                                onDatesChanged()
                                            }
                                        }
                                }
                                
                                Text("to")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 14)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("END DATE")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    TextField("YYYY-MM-DD", text: $endDateText)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(endDateText.isEmpty || parseDate(endDateText) != nil ? Color.white.opacity(0.08) : Color.orange.opacity(0.6), lineWidth: 1)
                                        )
                                        .frame(width: 105)
                                        .onChange(of: endDateText) { newValue in
                                            if let parsed = parseDate(newValue) {
                                                if parsed < startDate {
                                                    startDate = parsed
                                                }
                                                endDate = parsed
                                                onDatesChanged()
                                            }
                                        }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            
                            // Calendars Row
                            HStack(spacing: 12) {
                                // Start Calendar
                                VStack(spacing: 6) {
                                    HStack(spacing: 4) {
                                        Menu {
                                            ForEach(startMonthsList, id: \.1) { name, mVal in
                                                Button(name) {
                                                    jumpToMonth(mVal, isStart: true)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 3) {
                                                Text(monthName(for: startMonth))
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 6))
                                            }
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(5)
                                        }
                                        .menuStyle(.button)
                                        
                                        Menu {
                                            ForEach(startYearsList, id: \.self) { yVal in
                                                Button(String(yVal)) {
                                                    jumpToYear(yVal, isStart: true)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 3) {
                                                Text(String(startYear))
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 6))
                                            }
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(5)
                                        }
                                        .menuStyle(.button)
                                        
                                        Spacer()
                                    }
                                    
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { startDate },
                                            set: { newDate in
                                                startDate = newDate
                                                if startDate > endDate {
                                                    endDate = startDate
                                                }
                                                onDatesChanged()
                                            }
                                        ),
                                        in: ...endDate,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                                    .frame(width: 240, height: 195)
                                }
                                
                                VerticalDivider()
                                
                                // End Calendar
                                VStack(spacing: 6) {
                                    HStack(spacing: 4) {
                                        Menu {
                                            ForEach(endMonthsList, id: \.1) { name, mVal in
                                                Button(name) {
                                                    jumpToMonth(mVal, isStart: false)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 3) {
                                                Text(monthName(for: endMonth))
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 6))
                                            }
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(5)
                                        }
                                        .menuStyle(.button)
                                        
                                        Menu {
                                            ForEach(endYearsList, id: \.self) { yVal in
                                                Button(String(yVal)) {
                                                    jumpToYear(yVal, isStart: false)
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 3) {
                                                Text(String(endYear))
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 6))
                                            }
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(5)
                                        }
                                        .menuStyle(.button)
                                        
                                        Spacer()
                                    }
                                    
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { endDate },
                                            set: { newDate in
                                                endDate = newDate
                                                if endDate < startDate {
                                                    startDate = endDate
                                                }
                                                onDatesChanged()
                                            }
                                        ),
                                        in: startDate...,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.graphical)
                                    .labelsHidden()
                                    .frame(width: 240, height: 195)
                                }
                            }
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(width: 670, height: 290)
                }
            }
            .tint(tintColor)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            .onAppear {
                startDateText = formattedDate(startDate)
                endDateText = formattedDate(endDate)
            }
            .onChange(of: startDate) { newDate in
                startDateText = formattedDate(newDate)
            }
            .onChange(of: endDate) { newDate in
                endDateText = formattedDate(newDate)
            }
        }
    }
}

// MARK: - Helper Views
struct VerticalDivider: View {
    var body: some View {
        Divider()
            .background(Color.white.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
    }
}
