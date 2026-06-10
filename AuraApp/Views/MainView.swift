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
                                        HStack(spacing: 6) {
                                            DatePicker("", selection: Binding(
                                                get: { manager.customStartDate },
                                                set: { newValue in
                                                    manager.customStartDate = newValue
                                                    manager.applyFilter()
                                                }
                                            ), displayedComponents: .date)
                                            .labelsHidden()
                                            .controlSize(.small)
                                            .scaleEffect(0.85)
                                            .frame(width: 90)
                                            
                                            Text("to")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            
                                            DatePicker("", selection: Binding(
                                                get: { manager.customEndDate },
                                                set: { newValue in
                                                    manager.customEndDate = newValue
                                                    manager.applyFilter()
                                                }
                                            ), displayedComponents: .date)
                                            .labelsHidden()
                                            .controlSize(.small)
                                            .scaleEffect(0.85)
                                            .frame(width: 90)
                                        }
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
                                        HStack(spacing: 6) {
                                            DatePicker("", selection: Binding(
                                                get: { photosManager.customStartDate },
                                                set: { newValue in
                                                    photosManager.customStartDate = newValue
                                                    photosManager.applyFilter()
                                                }
                                            ), displayedComponents: .date)
                                            .labelsHidden()
                                            .controlSize(.small)
                                            .scaleEffect(0.85)
                                            .frame(width: 90)
                                            
                                            Text("to")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            
                                            DatePicker("", selection: Binding(
                                                get: { photosManager.customEndDate },
                                                set: { newValue in
                                                    photosManager.customEndDate = newValue
                                                    photosManager.applyFilter()
                                                }
                                            ), displayedComponents: .date)
                                            .labelsHidden()
                                            .controlSize(.small)
                                            .scaleEffect(0.85)
                                            .frame(width: 90)
                                        }
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
                    
                    // Pulsating center aperture icon
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(.emerald)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                        .shadow(color: Color.emerald.opacity(0.2), radius: 4)
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
