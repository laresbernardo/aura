import SwiftUI

struct MainView: View {
    @StateObject var manager = MusicLibraryManager()
    @State private var currentTab: Tab = .overview
    @State private var isSyncButtonHovered = false
    
    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case habits = "Listening Habits"
        case timeMachine = "Time Machine"
    }
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Premium Sidebar Layout
            VStack(alignment: .leading, spacing: 20) {
                // App Logo / Brand Section
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "music.note")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
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
                    
                    // Demo Mode Toggle Row
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(manager.isDemoMode ? "Demo Library" : "Live Connected")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                Text(manager.isDemoMode ? "Preview Mode Active" : "Connected to Music.app")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            // Active Glowing Badge
                            Circle()
                                .fill(manager.isDemoMode ? Color.purple : Color.emerald)
                                .frame(width: 8, height: 8)
                                .shadow(color: manager.isDemoMode ? .purple : .emerald, radius: 4)
                        }
                        
                        Toggle("", isOn: Binding(
                            get: { manager.isDemoMode },
                            set: { _ in manager.toggleMode() }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .labelsHidden()
                        .scaleEffect(0.85)
                    }
                    .padding(.horizontal, 12)
                    
                    // Sync Operations
                    if !manager.isDemoMode {
                        Button(action: {
                            Task { await manager.fetchLiveLibrary() }
                        }) {
                            HStack(spacing: 8) {
                                if manager.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11, weight: .semibold))
                                        .rotationEffect(.degrees(manager.isLoading ? 360 : 0))
                                        .animation(manager.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isLoading)
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
                        .padding(.horizontal, 12)
                        .disabled(manager.isLoading)
                    }
                }
                .padding(.bottom, 20)
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
                    if !manager.isDemoMode && manager.musicAppRunningState == .notRunning {
                        // App Offline State
                        MusicOfflineFallbackView(manager: manager)
                            .transition(.opacity)
                    } else if !manager.isDemoMode && manager.musicAppRunningState == .permissionDenied {
                        // Permission Block State
                        PermissionBlockedFallbackView()
                            .transition(.opacity)
                    } else {
                        // Normal Operations
                        Group {
                            switch currentTab {
                            case .overview:
                                OverviewDashboardView(manager: manager)
                            case .habits:
                                ListeningHabitsView(manager: manager)
                            case .timeMachine:
                                TimeMachineView(manager: manager)
                            }
                        }
                        .padding(28)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
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
        case .timeMachine: return "clock.arrow.2.circlepath"
        }
    }
}

// MARK: - Fallback: Music App Offline View
struct MusicOfflineFallbackView: View {
    @ObservedObject var manager: MusicLibraryManager
    @State private var isHovered = false
    
    var body: some View {
        GlassCard(cornerRadius: 20, shadowRadius: 16) {
            VStack(spacing: 22) {
                // Logo Icon
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.purple)
                }
                
                VStack(spacing: 8) {
                    Text("macOS Music app is Offline")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Aura needs to query the native Music app to load live statistics.\nPlease launch it to establish a secure connection.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 20)
                
                Button(action: {
                    manager.launchMusicApp()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("Launch Music App & Sync")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isHovered ? Color.purple.opacity(0.95) : Color.purple.opacity(0.8))
                            .shadow(color: .purple.opacity(0.35), radius: 8, y: 4)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHovered = hovering
                }
                
                if let err = manager.syncError {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
            }
            .padding(40)
        }
        .frame(width: 460)
    }
}

// MARK: - Fallback: Permission Blocked View
struct PermissionBlockedFallbackView: View {
    var body: some View {
        GlassCard(cornerRadius: 20, shadowRadius: 16) {
            VStack(spacing: 24) {
                // Alert Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                }
                
                VStack(spacing: 8) {
                    Text("Automation Permissions Required")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("To build your personal music dashboard, macOS requires that you authorize Aura to automate and query the Music app.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 10)
                
                Divider().background(Color.white.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Grant Permission:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .textCase(.uppercase)
                    
                    HStack(alignment: .top, spacing: 10) {
                        Text("1.")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Open **System Settings** on your Mac.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 10) {
                        Text("2.")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Navigate to **Privacy & Security** > **Automation**.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 10) {
                        Text("3.")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Find **Aura** in the list and toggle **Music** to ON.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
            }
            .padding(40)
        }
        .frame(width: 480)
    }
}
