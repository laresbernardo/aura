import SwiftUI
import AppKit

@MainActor
final class UpdateChecker: ObservableObject {
    @Published var available: UpdateManifest?
    @Published var checking = false
    @Published var message: String?
    private let defaults: UserDefaults
    private let fetch: () async throws -> UpdateManifest
    private let version: String
    private let build: Int
    private let now: () -> Date
    private var launched = false
    private let lastAttemptKey = "aura.update.lastAttempt"
    private let dismissedKey = "aura.update.dismissedRelease"
    static let interval: TimeInterval = 24 * 60 * 60

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main,
         now: @escaping () -> Date = Date.init,
         fetch: @escaping () async throws -> UpdateManifest = UpdateTransport.fetch) {
        self.defaults = defaults
        self.now = now
        self.fetch = fetch
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        build = Int(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0
    }
    func launch() async {
        guard !launched else { return }
        launched = true
        await check(force: true)
    }
    func reactivate() async {
        guard launched else { return }
        await check()
    }
    func check(force: Bool = false, manual: Bool = false) async {
        guard !checking else { return }
        let date = now()
        if !force && !manual, let last = defaults.object(forKey: lastAttemptKey) as? Date,
           date.timeIntervalSince(last) < Self.interval { return }
        // Record attempts, including failures, so offline activation never causes a request loop.
        defaults.set(date, forKey: lastAttemptKey)
        checking = true
        defer { checking = false }
        do {
            let release = try await fetch()
            let os = ProcessInfo.processInfo.operatingSystemVersion
            #if arch(arm64)
            let architecture = "arm64"
            #else
            let architecture = "x86_64"
            #endif
            guard release.isCompatible(macOS: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)", architecture: architecture) else {
                available = nil
                if manual { message = "The latest release requires a different macOS version or processor." }
                return
            }
            guard release.isNewer(version: version, build: build) else {
                available = nil
                if manual { message = "Aura is up to date." }
                return
            }
            if manual || defaults.string(forKey: dismissedKey) != release.identity { available = release }
        } catch {
            // Automatic failures stay silent. An explicit check gets useful feedback.
            if manual { message = "Could not check for updates. Please try again later." }
        }
    }
    func dismiss() {
        if let release = available { defaults.set(release.identity, forKey: dismissedKey) }
        available = nil
    }
    func download() {
        guard let release = available, UpdateManifest.official(release.downloadURL) else { return }
        NSWorkspace.shared.open(release.downloadURL)
        dismiss()
    }
}

struct UpdateNotice: View {
    @ObservedObject var updates: UpdateChecker
    var body: some View {
        if let release = updates.available {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { title(release); Spacer(minLength: 8); actions }
                VStack(alignment: .leading, spacing: 8) { title(release); actions }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12)))
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }
    private func title(_ release: UpdateManifest) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("New version available").font(.callout.weight(.semibold))
            Text("Aura \(release.version) · Quit Aura, then drag the update to Applications.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var actions: some View {
        HStack(spacing: 8) {
            Button("Download free update") { updates.download() }.buttonStyle(.borderedProminent).tint(.purple)
            Button("Later") { updates.dismiss() }.buttonStyle(.bordered)
        }.fixedSize()
    }
}
