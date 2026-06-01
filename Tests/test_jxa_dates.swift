import Foundation

func runOsaScript(_ script: String) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-l", "JavaScript", "-e", script]
    
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    
    do {
        try process.run()
        
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        process.waitUntilExit()
        
        let status = process.terminationStatus
        if status == 0 {
            return String(data: data, encoding: .utf8) ?? "Empty response"
        } else {
            return "ERROR: " + (String(data: errData, encoding: .utf8) ?? "Unknown JXA error")
        }
    } catch {
        return "FATAL: \(error)"
    }
}

let testScript = """
(function() {
    var app = Application("Music");
    if (!app.running()) {
        return JSON.stringify({ error: "Music app not running" });
    }
    var library = app.libraryPlaylists[0];
    var fileTracks = library.fileTracks;
    
    var names = [];
    var artists = [];
    var datesAdded = [];
    var years = [];
    var playCounts = [];
    
    try { names = fileTracks.name(); } catch(e) {}
    try { artists = fileTracks.artist(); } catch(e) {}
    try { datesAdded = fileTracks.dateAdded(); } catch(e) {}
    try { years = fileTracks.year(); } catch(e) {}
    try { playCounts = fileTracks.playedCount(); } catch(e) {}
    
    var results = [];
    var len = names.length;
    
    for (var i = 0; i < len; i++) {
        var d = datesAdded[i];
        var dStr = "";
        var yearAdded = 0;
        if (d) {
            dStr = d.toString();
            if (d.getFullYear) {
                yearAdded = d.getFullYear();
            } else {
                var dp = Date.parse(dStr);
                if (!isNaN(dp)) {
                    yearAdded = new Date(dp).getFullYear();
                }
            }
        }
        
        // Let's grab track year too
        var yr = years[i] || 0;
        
        if (yearAdded >= 2024 || yr >= 2024) {
            results.push({
                name: names[i] || "Unknown",
                artist: artists[i] || "Unknown",
                year: yr,
                dateAddedRaw: dStr,
                yearAdded: yearAdded,
                playCount: playCounts[i] || 0
            });
        }
    }
    
    // Sort by yearAdded descending
    results.sort(function(a, b) {
        return b.yearAdded - a.yearAdded;
    });
    
    return JSON.stringify({
        totalMatched: results.length,
        samples: results.slice(0, 30)
    });
})();
"""

print("Running JXA to query 2024+ tracks in macOS Music...")
let output = runOsaScript(testScript)
print("JXA Query Result:")
print(output)
