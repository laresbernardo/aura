import Foundation

@main
struct UpdateTests {
    @MainActor static func main() async throws {
        let release = UpdateManifest(appID: "com.aura.MusicDashboard", version: "1.1.0", build: 129,
            minimumMacOS: "13.0", architectures: ["arm64", "x86_64"],
            downloadURL: URL(string: "https://aura.bervos.org/assets/Aura.dmg")!, notes: nil)
        assert(ReleaseVersion("1.10")! > ReleaseVersion("1.9.9")!)
        assert(ReleaseVersion("1.1")! == ReleaseVersion("1.1.0")!)
        for value in ["", "1..0", "1.-1", "1.2.3.4", "1.beta", "999999999999999999999999"] { assert(ReleaseVersion(value) == nil) }
        assert(release.isNewer(version: "1.0.127", build: 128))
        assert(!release.isNewer(version: "1.1.0", build: 129))
        assert(release.isNewer(version: "1.1.0", build: 128))
        assert(!release.isNewer(version: "1.2.0", build: 1))
        assert(!release.isCompatible(macOS: "12.9", architecture: "arm64"))
        assert(!release.isCompatible(macOS: "13.0", architecture: "other"))
        for url in ["http://aura.bervos.org/assets/Aura.dmg", "https://evil.test", "https://aura.bervos.org.evil.test", "https://user@aura.bervos.org", "https://aura.bervos.org:444"] { assert(!UpdateManifest.official(URL(string: url)!)) }
        var json: [String: Any] = ["appID": release.appID, "version": release.version, "build": release.build,
            "minimumMacOS": release.minimumMacOS, "architectures": release.architectures, "downloadURL": release.downloadURL.absoluteString]
        _ = try UpdateManifest.decode(JSONSerialization.data(withJSONObject: json))
        for (key, value) in [("appID", "other"), ("version", "bad"), ("downloadURL", "https://aura.bervos.org/other"), ("minimumMacOS", "bad")] {
            var invalid = json; invalid[key] = value
            do { _ = try UpdateManifest.decode(JSONSerialization.data(withJSONObject: invalid)); fatalError("Accepted invalid \(key)") } catch {}
        }
        json["notes"] = String(repeating: "x", count: 33_000)
        do { _ = try UpdateManifest.decode(JSONSerialization.data(withJSONObject: json)); fatalError("Accepted oversized JSON") } catch {}
        let suite = "AuraUpdateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = Date()
        var attempts = 0
        let checker = UpdateChecker(defaults: defaults, now: { date }, fetch: { attempts += 1; return release })
        await checker.launch(); assert(attempts == 1 && checker.available != nil)
        await checker.launch(); await checker.reactivate(); assert(attempts == 1)
        checker.dismiss(); assert(checker.available == nil)
        date = date.addingTimeInterval(UpdateChecker.interval - 1)
        await checker.reactivate(); assert(attempts == 1)
        date = date.addingTimeInterval(1)
        await checker.reactivate(); assert(attempts == 2 && checker.available == nil)
        await checker.check(manual: true); assert(attempts == 3 && checker.available != nil)
        checker.dismiss()
        let restored = UpdateChecker(defaults: defaults, now: { date }, fetch: { return release })
        await restored.launch(); assert(restored.available == nil)
        let offline = UpdateChecker(defaults: defaults, now: { date }, fetch: { attempts += 1; throw URLError(.notConnectedToInternet) })
        await offline.launch(); assert(offline.message == nil)
        let previous = attempts
        await offline.reactivate(); assert(attempts == previous)
        await offline.check(manual: true); assert(offline.message != nil)
        var slowAttempts = 0
        let slow = UpdateChecker(defaults: defaults, fetch: {
            slowAttempts += 1
            try await Task.sleep(nanoseconds: 50_000_000)
            return release
        })
        let first = Task { await slow.check(manual: true) }
        await Task.yield()
        await slow.check(manual: true)
        await first.value
        assert(slowAttempts == 1)
        print("PASS: version comparison, strict validation, compatibility, launch, 24h throttle, persisted dismissal, manual override, offline silence and in-flight coalescing")
    }
}
