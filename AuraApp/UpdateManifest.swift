import Foundation

struct ReleaseVersion: Comparable {
    let parts: [Int]
    init?(_ value: String) {
        let fields = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(fields.count), fields.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }),
              fields.allSatisfy({ Int($0) != nil }) else { return nil }
        parts = fields.map { Int($0)! } + Array(repeating: 0, count: 3 - fields.count)
    }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.parts.lexicographicallyPrecedes(rhs.parts) }
}

struct UpdateManifest: Decodable {
    let appID: String
    let version: String
    let build: Int
    let minimumMacOS: String
    let architectures: [String]
    let downloadURL: URL
    let notes: String?
    var identity: String { "\(version):\(build)" }

    static func official(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "aura.bervos.org" &&
        (url.port == nil || url.port == 443) && url.user == nil && url.password == nil
    }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 32_768 else { throw UpdateError.invalidManifest }
        let release = try JSONDecoder().decode(Self.self, from: data)
        guard release.appID == "com.aura.MusicDashboard", ReleaseVersion(release.version) != nil,
              ReleaseVersion(release.minimumMacOS) != nil, release.build > 0,
              !release.architectures.isEmpty, release.architectures.allSatisfy({ ["arm64", "x86_64"].contains($0) }),
              official(release.downloadURL), release.downloadURL.path == "/assets/Aura.dmg",
              release.downloadURL.query == nil, release.downloadURL.fragment == nil,
              (release.notes?.count ?? 0) <= 2_000 else { throw UpdateError.invalidManifest }
        return release
    }
    func isNewer(version installed: String, build installedBuild: Int) -> Bool {
        guard let current = ReleaseVersion(installed), let latest = ReleaseVersion(version) else { return false }
        return latest > current || (latest == current && build > installedBuild)
    }
    func isCompatible(macOS: String, architecture: String) -> Bool {
        guard let current = ReleaseVersion(macOS), let minimum = ReleaseVersion(minimumMacOS) else { return false }
        return current >= minimum && architectures.contains(architecture)
    }
}

enum UpdateError: Error { case invalidManifest, invalidResponse }

// Never follow a redirect to a different origin, or send cookies or credentials.
final class UpdateRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map(UpdateManifest.official) == true ? request : nil)
    }
}

struct UpdateTransport {
    static let manifestURL = URL(string: "https://aura.bervos.org/version.json")!
    static func fetch() async throws -> UpdateManifest {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config, delegate: UpdateRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: manifestURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url.map(UpdateManifest.official) == true,
              http.mimeType == "application/json" else { throw UpdateError.invalidResponse }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 32_768 else { throw UpdateError.invalidManifest }
            data.append(byte)
        }
        return try UpdateManifest.decode(data)
    }
}
