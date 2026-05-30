import SwiftUI

struct MainView: View {
    @StateObject var manager = MusicLibraryManager()
    @State private var currentTab: Tab = .overview
    @State private var isSyncButtonHovered = false
    
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case habits = "Listening Habits"
        case artists = "Artist Hall"
        case persona = "Aura Profile"
        case temporal = "Sonic Rhythms"
        case timeMachine = "Time Machine"
    }
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Premium Sidebar Layout
            VStack(alignment: .leading, spacing: 20) {
                // App Logo / Brand Section
                HStack(spacing: 12) {
                    if let logoURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
                       let nsImage = NSImage(contentsOf: logoURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    } else {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AURA")
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(.white)
                        Text("Music Analytics")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // Navigation Links
                VStack(spacing: 6) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                currentTab = tab
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: tabIcon(for: tab))
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 18)
                                    .foregroundColor(currentTab == tab ? .white : .secondary)
                                
                                Text(tab.rawValue)
                                    .font(.body)
                                    .fontWeight(currentTab == tab ? .semibold : .regular)
                                    .foregroundColor(currentTab == tab ? .white : .secondary)
                                
                                Spacer()
                                
                                if currentTab == tab {
                                    Circle()
                                        .fill(Color.purple)
                                        .frame(width: 5, height: 5)
                                        .shadow(color: .purple, radius: 3)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(currentTab == tab ? Color.white.opacity(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                // Sidebar Footer / Environment Config
                VStack(spacing: 14) {
                    Divider().background(Color.white.opacity(0.08))
                    
                    // Library Source Mode Picker Row
                    VStack(alignment: .leading, spacing: 10) {
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
                    
                    // Operations per Connection Mode
                    if manager.sourceMode != .demo {
                        VStack(spacing: 8) {
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
                                        ProgressView()
                                            .controlSize(.small)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    
                                    Text(manager.isLoading ? "Syncing..." : "Sync Now")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isSyncButtonHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                isSyncButtonHovered = hovering
                            }
                            .disabled(manager.isLoading)
                            
                            if manager.sourceMode == .xml {
                                Button(action: {
                                    Task { await manager.selectXMLFileManually() }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.badge.plus")
                                            .font(.system(size: 10))
                                        Text("Change XML Source...")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.02))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .disabled(manager.isLoading)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    
                    // Application Version & Credits Footer
                    VStack(spacing: 6) {
                        HStack {
                            Spacer()
                            Text("Aura \(manager.appVersionString)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.5))
                            Spacer()
                        }
                        
                        Button(action: {
                            if let url = URL(string: "https://bervos.org") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                if let logoURL = Bundle.main.url(forResource: "BervosLogo", withExtension: "png"),
                                   let nsImage = NSImage(contentsOf: logoURL) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 14, height: 14)
                                        .colorMultiply(.white.opacity(0.7))
                                }
                                
                                Text("by BERVOS")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 12)
            }
            .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
            .frame(minWidth: 220)
        } detail: {
            // MARK: - Detail Views & Fallback Screens
            ZStack {
                // Absolute Deep Obsidian Glassy Background
                LinearGradient(
                    colors: [
                        Color(red: 11/255, green: 10/255, blue: 18/255),
                        Color(red: 18/255, green: 18/255, blue: 30/255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Main Dashboard Dynamic Display
                VStack {
                    if !manager.isDemoMode && manager.isLoading {
                        ProgressView("Reading Music library…")
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    } else if !manager.isDemoMode, let errorMsg = manager.syncError {
                        // XML not found or unreadable — show actionable guidance
                        XMLErrorFallbackView(message: errorMsg, manager: manager)
                            .transition(.opacity)
                    } else {
                        // Normal Operations
                        VStack(spacing: 0) {
                            // Smart Pinned Header Filter Bar
                            HStack {
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Text("Time Range:")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    Picker("", selection: Binding(
                                        get: { manager.currentFilter },
                                        set: { newValue in
                                            manager.currentFilter = newValue
                                            manager.applyFilter()
                                        }
                                    )) {
                                        Text("All Time").tag(TimeFilter.allTime)
                                        Text(manager.currentYearString).tag(TimeFilter.currentYear)
                                        Text(manager.previousYearString).tag(TimeFilter.previousYear)
                                        Text(manager.twoYearsAgoString).tag(TimeFilter.twoYearsAgo)
                                        Text("Custom").tag(TimeFilter.customRange)
                                    }
                                    .pickerStyle(.segmented)
                                    .scaleEffect(0.9)
                                    .frame(width: 320)
                                }
                                
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
                                switch currentTab {
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
                }
            }
        }
        .frame(minWidth: 980, minHeight: 650)
    }
    
    // Helper: Tabs to Icons
    private func tabIcon(for tab: Tab) -> String {
        switch tab {
        case .overview: return "chart.bar.doc.horizontal.fill"
        case .habits: return "waveform.path.ecg.rectangle"
        case .artists: return "person.3.sequence.fill"
        case .persona: return "sparkles.rectangle.stack.fill"
        case .temporal: return "clock.badge.checkmark"
        case .timeMachine: return "clock.arrow.2.circlepath"
        }
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

