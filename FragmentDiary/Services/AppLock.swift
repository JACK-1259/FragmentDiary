import Foundation
import LocalAuthentication
import Observation

@Observable
final class AppLock {
    enum Availability {
        case faceID, touchID, opticID, passcode, unavailable
    }

    var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "lockEnabled") }
    }
    private(set) var availability: Availability

    init() {
        enabled = UserDefaults.standard.object(forKey: "lockEnabled") as? Bool ?? true
        availability = Self.probe()
    }

    var isEffective: Bool { enabled && availability != .unavailable }

    var methodName: String {
        switch availability {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        case .passcode, .unavailable: "기기 암호"
        }
    }

    var symbolName: String {
        switch availability {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        case .passcode, .unavailable: "lock.fill"
        }
    }

    func refreshAvailability() {
        availability = Self.probe()
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "취소"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "일기를 열려면 인증이 필요해요")
        } catch {
            return false
        }
    }

    private static func probe() -> Availability {
        let context = LAContext()
        // biometryType reports hardware support, so check enrollment separately to avoid promising Face ID and showing a passcode sheet.
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
            switch context.biometryType {
            case .faceID: return .faceID
            case .touchID: return .touchID
            case .opticID: return .opticID
            default: break
            }
        }
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) ? .passcode : .unavailable
    }
}
