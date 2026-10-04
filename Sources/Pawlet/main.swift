import AppKit

if let index = CommandLine.arguments.firstIndex(of: "--verify-imports") {
    do { try TransferTests.verify(Array(CommandLine.arguments.dropFirst(index + 1))) }
    catch { fputs("Import verification failed: \(error.localizedDescription)\n", stderr); exit(1) }
} else if CommandLine.arguments.contains("--self-test") {
    do { try ProjectTests.run() } catch { fputs("Tests failed: \(error.localizedDescription)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
