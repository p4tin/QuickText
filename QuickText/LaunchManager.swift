import Foundation
import ServiceManagement
import Combine

class LaunchManager: ObservableObject {
    @Published var isEnabled: Bool = false {
        didSet {
            toggleLaunchAtLogin()
        }
    }

    // FIX: The property name in Swift is 'mainApp'
    private let service = SMAppService.mainApp

    init() {
        // Fetch the actual status from the system
        self.isEnabled = (service.status == SMAppService.Status.enabled)
    }

    private func toggleLaunchAtLogin() {
        guard isEnabled != (service.status == SMAppService.Status.enabled) else { return }

        do {
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("Failed to update Login Item status: \(error)")
            DispatchQueue.main.async {
                self.isEnabled = (self.service.status == SMAppService.Status.enabled)
            }
        }
    }
}
