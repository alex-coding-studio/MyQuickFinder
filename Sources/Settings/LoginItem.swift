import AppKit
import Foundation
import ServiceManagement

@MainActor
@Observable
final class LoginItemSettings {
    private(set) var isEnabled: Bool
    private(set) var failureMessage: String?

    private let service: SMAppService

    var needsApproval: Bool {
        service.status == .requiresApproval
    }

    init(service: SMAppService = .mainApp) {
        self.service = service
        isEnabled = service.status == .enabled
    }

    func refresh() {
        isEnabled = service.status == .enabled
        if service.status == .requiresApproval {
            failureMessage = String(localized: "settings.launch.needsApproval")
        } else {
            failureMessage = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            failureMessage = nil
        } catch {
            failureMessage = (error as NSError).localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
