import Foundation
import ServiceManagement

final class LoginItemService {
    func status() -> LaunchItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            .enabled
        case .notRegistered:
            .disabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unknown
        }
    }

    func setEnabled(_ enabled: Bool) throws -> LaunchItemStatus {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
            try SMAppService.mainApp.unregister()
        }
        return status()
    }
}
