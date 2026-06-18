import RuralWallpaperCore

enum DisplaySelection {
    static func isEnabled(displayID: String, settings: AppSettings) -> Bool {
        settings.enabledDisplayIDs.isEmpty || settings.enabledDisplayIDs.contains(displayID)
    }

    static func update(
        displayID: String,
        enabled: Bool,
        displays: [DisplayTarget],
        settings: inout AppSettings
    ) {
        let allDisplayIDs = Set(displays.map(\.id))
        guard allDisplayIDs.contains(displayID) else {
            return
        }

        if settings.enabledDisplayIDs.isEmpty {
            settings.enabledDisplayIDs = allDisplayIDs
        }

        if enabled {
            settings.enabledDisplayIDs.insert(displayID)
            if settings.enabledDisplayIDs == allDisplayIDs {
                settings.enabledDisplayIDs = []
            }
        } else if settings.enabledDisplayIDs.count > 1 {
            settings.enabledDisplayIDs.remove(displayID)
        }
    }
}
