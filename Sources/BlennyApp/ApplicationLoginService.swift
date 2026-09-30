import BlennyCore
import ServiceManagement

@MainActor
enum ApplicationLoginService {
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            else if service.status != .enabled { try service.register() }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }
    static func presentation(failureMessage: String? = nil) -> LaunchAtLoginPresentationState {
        let availability: LaunchAtLoginAvailability
        switch SMAppService.mainApp.status {
        case .notRegistered: availability = .disabled
        case .enabled: availability = .enabled
        case .requiresApproval: availability = .requiresApproval
        case .notFound: availability = .notFound
        @unknown default: availability = .notFound
        }
        return LaunchAtLoginPresentationState(availability: availability, failureMessage: failureMessage)
    }
}
