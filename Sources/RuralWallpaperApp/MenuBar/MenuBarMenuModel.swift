import Foundation

struct MenuBarMenuModel: Equatable {
    static func sections(
        isGenerating: Bool,
        hasLastPreview: Bool
    ) -> [MenuBarMenuSection] {
        var primaryItems: [MenuBarMenuItem] = []
        if isGenerating {
            primaryItems.append(MenuBarMenuItem(title: "Generating", role: .loading, isEnabled: false))
        }

        primaryItems.append(contentsOf: [
            MenuBarMenuItem(title: "Select Display", role: .submenu, isEnabled: true),
            MenuBarMenuItem(title: "Choose Image", role: .action, isEnabled: !isGenerating),
            MenuBarMenuItem(title: "Generate Preview", role: .action, isEnabled: !isGenerating)
        ])

        if isGenerating {
            primaryItems.append(MenuBarMenuItem(title: "Cancel Generation", role: .action, isEnabled: true))
        }

        return [
            MenuBarMenuSection(items: primaryItems),
            MenuBarMenuSection(items: [
                MenuBarMenuItem(title: "Open Last Preview", role: .action, isEnabled: hasLastPreview),
                MenuBarMenuItem(title: "Open Logs", role: .action, isEnabled: true)
            ]),
            MenuBarMenuSection(items: [
                MenuBarMenuItem(title: "Settings", role: .action, isEnabled: true),
                MenuBarMenuItem(title: "Quit", role: .action, isEnabled: true)
            ])
        ]
    }
}

struct MenuBarMenuSection: Equatable {
    var items: [MenuBarMenuItem]
}

struct MenuBarMenuItem: Equatable {
    enum Role: Equatable {
        case action
        case submenu
        case loading
    }

    var title: String
    var role: Role
    var isEnabled: Bool
}
