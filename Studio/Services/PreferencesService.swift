import Foundation

protocol PreferencesServiceProtocol: AnyObject {
    var lastBundleID: String? { get set }
}

class PreferencesService: PreferencesServiceProtocol {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var lastBundleID: String? {
        get {
            userDefaults.string(forKey: Keys.lastBundleID)
        }
        set {
            if let value = newValue {
                userDefaults.set(value, forKey: Keys.lastBundleID)
            } else {
                userDefaults.removeObject(forKey: Keys.lastBundleID)
            }
        }
    }

    private enum Keys {
        static let lastBundleID = "lastBundleID"
    }
}
