import AppKit

if CommandLine.arguments.contains("--self-test") {
    do { try ProjectTests.run() } catch { fputs("Tests failed: \(error.localizedDescription)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
