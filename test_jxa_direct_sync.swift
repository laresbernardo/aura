import Foundation

func runOsaScript(_ script: String) async -> Result<String, Error> {
    return await Task.detached(priority: .userInitiated) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", script]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            
            // Read all data first to prevent process block/deadlock when buffer exceeds 64KB
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            process.waitUntilExit()
            
            let status = process.terminationStatus
            if status == 0 {
                if let output = String(data: data, encoding: .utf8) {
                    return .success(output)
                } else {
                    return .failure(NSError(domain: "OsaScriptError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read string output."]))
                }
            } else {
                let errString = String(data: errData, encoding: .utf8) ?? "Unknown JXA error"
                return .failure(NSError(domain: "OsaScriptError", code: Int(status), userInfo: [NSLocalizedDescriptionKey: errString]))
            }
        } catch {
            return .failure(error)
        }
    }.value
}

let jxaScript = #"""
(function() {
    var app = Application("Music");
    if (!app.running()) {
        return JSON.stringify({ "error": "Music application is not running." });
    }
    
    var library;
    try {
        library = app.libraryPlaylists[0];
        if (!library) {
            return JSON.stringify({ "error": "Library playlist is unavailable." });
        }
    } catch(e) {
        return JSON.stringify({ "error": "Could not access Music Library. Please check automation permissions." });
    }
    
    var tracks = library.fileTracks;
    
    var count = 0;
    try {
        count = tracks.length;
    } catch(e) {
        return JSON.stringify({ "error": "Could not query track count. Permissions may be restricted." });
    }
    
    if (count === 0) {
        return JSON.stringify([]);
    }
    
    var names = [];
    var artists = [];
    var albums = [];
    var genres = [];
    var playCounts = [];
    var skipCounts = [];
    var ratings = [];
    var datesAdded = [];
    var lastsPlayed = [];
    var years = [];
    
    try { names = tracks.name(); } catch(e) {}
    try { artists = tracks.artist(); } catch(e) {}
    try { albums = tracks.album(); } catch(e) {}
    try { genres = tracks.genre(); } catch(e) {}
    try { playCounts = tracks.playedCount(); } catch(e) {}
    try { skipCounts = tracks.skippedCount(); } catch(e) {}
    try { ratings = tracks.rating(); } catch(e) {}
    try { datesAdded = tracks.dateAdded(); } catch(e) {}
    try { lastsPlayed = tracks.playedDate(); } catch(e) {}
    try { years = tracks.year(); } catch(e) {}
    
    function parseDate(d) {
        if (!d) return null;
        try {
            if (typeof d === 'number') return d;
            if (d.getTime) {
                var t = d.getTime();
                if (!isNaN(t)) return t / 1000;
            }
            var s = d.toString();
            if (s) {
                var t = Date.parse(s);
                if (!isNaN(t)) return t / 1000;
                var d2 = new Date(s);
                if (d2 && d2.getTime) {
                    var t2 = d2.getTime();
                    if (!isNaN(t2)) return t2 / 1000;
                }
            }
        } catch(e) {}
        return null;
    }
    
    var list = [];
    var itemsCount = names.length;
    for (var i = 0; i < itemsCount; i++) {
        var tAdded = parseDate(datesAdded[i]);
        var tPlayed = parseDate(lastsPlayed[i]);
        
        list.push({
            "name": names[i] || "Unknown Track",
            "artist": artists[i] || "Unknown Artist",
            "album": albums[i] || "Unknown Album",
            "genre": genres[i] || "Unknown Genre",
            "playCount": playCounts[i] || 0,
            "skipCount": skipCounts[i] || 0,
            "rating": ratings[i] || 0,
            "dateAdded": tAdded,
            "lastPlayed": tPlayed,
            "year": years[i] || 0
        });
    }
    return JSON.stringify(list);
})();
"""#

Task {
    print("Running full direct sync JXA script...")
    let start = Date()
    let result = await runOsaScript(jxaScript)
    let duration = Date().timeIntervalSince(start)
    print("Finished in \(duration)s")
    
    switch result {
    case .success(let output):
        print("Success! Output length: \(output.count) characters")
        if let data = output.data(using: .utf8) {
            if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("Parsed \(array.count) tracks successfully!")
            } else {
                print("Failed to parse JSON. First 200 chars: \(output.prefix(200))")
            }
        }
    case .failure(let error):
        print("Failure: \(error.localizedDescription)")
    }
    exit(0)
}

dispatchMain()
