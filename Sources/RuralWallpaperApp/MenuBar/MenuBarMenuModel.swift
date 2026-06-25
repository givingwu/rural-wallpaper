import Foundation

struct MenuBarMenuModel: Equatable {
    static func sections(
        isGenerating: Bool,
        hasLastPreview: Bool,
        generateStatus: GenerateStatus,
        now: Date = Date()
    ) -> [MenuBarMenuSection] {
        let statusItems = statusSectionItems(
            generateStatus: generateStatus,
            isGenerating: isGenerating,
            now: now
        )
        var primaryItems: [MenuBarMenuItem] = []

        primaryItems.append(contentsOf: [
            MenuBarMenuItem(title: "Select Display", role: .submenu, isEnabled: true),
            MenuBarMenuItem(title: "Choose Image", role: .action, isEnabled: !isGenerating),
            MenuBarMenuItem(title: "Generate Preview", role: .action, isEnabled: !isGenerating)
        ])

        if isGenerating {
            primaryItems.append(MenuBarMenuItem(title: "Cancel Generation", role: .action, isEnabled: true))
        }

        return [
            MenuBarMenuSection(items: statusItems),
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

    private static func statusSectionItems(
        generateStatus: GenerateStatus,
        isGenerating: Bool,
        now: Date
    ) -> [MenuBarMenuItem] {
        var items = [
            MenuBarMenuItem(title: "Generate Status", role: .statusHeader, isEnabled: false),
            MenuBarMenuItem(
                title: generateStatus.primaryLine(now: now),
                role: isGenerating ? .loading : .statusDetail,
                isEnabled: false
            )
        ]

        if let sourceLine = generateStatus.sourceLine {
            items.append(MenuBarMenuItem(title: sourceLine, role: .statusDetail, isEnabled: false))
        }
        if let workingSourceLine = generateStatus.workingSourceLine {
            items.append(MenuBarMenuItem(title: workingSourceLine, role: .statusDetail, isEnabled: false))
        }
        if let targetLine = generateStatus.targetLine {
            items.append(MenuBarMenuItem(title: targetLine, role: .statusDetail, isEnabled: false))
        }
        if let wordsLine = generateStatus.wordsLine {
            items.append(MenuBarMenuItem(title: wordsLine, role: .statusDetail, isEnabled: false))
        }
        if !isGenerating, let previewLine = generateStatus.previewLine {
            items.append(MenuBarMenuItem(title: previewLine, role: .statusDetail, isEnabled: false))
        }

        return items
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
        case statusHeader
        case statusDetail
    }

    var title: String
    var role: Role
    var isEnabled: Bool
}
