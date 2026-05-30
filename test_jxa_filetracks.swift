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
        process.waitUntilExit()
        
        let status = process.terminationStatus
        if status == 0 {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? "Empty response"
        } else {
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
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
        return "Music app not running";
    }
    var library = app.libraryPlaylists[0];
    
    var start = new Date().getTime();
    
    // Direct bulk queries on unfiltered local fileTracks collection
    var fileTracks = library.fileTracks;
    
    var names = [];
    var artists = [];
    var datesAdded = [];
    
    try { names = fileTracks.name(); } catch(e) { return "names error: " + e.message; }
    try { artists = fileTracks.artist(); } catch(e) { return "artists error: " + e.message; }
    try { datesAdded = fileTracks.dateAdded(); } catch(e) { return "datesAdded error: " + e.message; }
    
    var end = new Date().getTime();
    
    return "Fetched " + names.length + " fileTrack names, " + artists.length + " artists, and " + datesAdded.length + " dates in " + (end - start) + "ms";
})();
"""

print("Running JXA fileTracks bulk query performance test...")
let output = runOsaScript(testScript)
print("--------------------------------------------------")
print(output)
print("--------------------------------------------------")
