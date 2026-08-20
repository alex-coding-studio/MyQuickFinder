import AppKit
import MyQuickFinderKit

enum SystemActions {
    static func revealInFinder(_ url: URL, isDirectory: Bool) {
        if isDirectory {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    static func copyPath(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.standardizedFileURL.path, forType: .string)
    }

    static func openFullDiskAccessSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    static func localizedDisplayName(for url: URL) -> String {
        let name = FileManager.default.displayName(atPath: url.path)
        return name.isEmpty ? PathDisplay.name(for: url) : name
    }
}

struct SystemTerminalLauncher: TerminalLauncher {
    static let terminalBundleIdentifier = "com.apple.Terminal"

    func open(_ directory: URL) throws {
        guard let terminal = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.terminalBundleIdentifier
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: terminal,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}
