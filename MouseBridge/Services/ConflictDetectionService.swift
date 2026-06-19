import AppKit
import Foundation

struct RunningApplicationSnapshot: Equatable, Sendable {
    var localizedName: String?
    var bundleIdentifier: String?
}

struct InputToolConflictDetector {
    private struct KnownTool {
        var displayName: String
        var nameFragments: [String]
        var bundleIdentifierFragments: [String]
    }

    private let knownTools: [KnownTool] = [
        KnownTool(displayName: "Logi Options+", nameFragments: ["logi options", "logitech options"], bundleIdentifierFragments: ["logi", "logitech"]),
        KnownTool(displayName: "Karabiner-Elements", nameFragments: ["karabiner"], bundleIdentifierFragments: ["karabiner"]),
        KnownTool(displayName: "BetterTouchTool", nameFragments: ["bettertouchtool"], bundleIdentifierFragments: ["bettertouchtool"]),
        KnownTool(displayName: "Mos", nameFragments: ["mos"], bundleIdentifierFragments: ["mos"]),
        KnownTool(displayName: "Mac Mouse Fix", nameFragments: ["mac mouse fix"], bundleIdentifierFragments: ["mac-mouse-fix", "macmousefix"]),
        KnownTool(displayName: "LinearMouse", nameFragments: ["linearmouse", "linear mouse"], bundleIdentifierFragments: ["linearmouse"]),
        KnownTool(displayName: "SteerMouse", nameFragments: ["steermouse", "steer mouse"], bundleIdentifierFragments: ["steermouse"])
    ]

    func detect(in applications: [RunningApplicationSnapshot]) -> [ConflictingInputTool] {
        var results: [ConflictingInputTool] = []
        var seen = Set<String>()

        for application in applications {
            let name = application.localizedName ?? ""
            let bundleIdentifier = application.bundleIdentifier ?? ""
            let normalizedName = name.lowercased()
            let normalizedBundleIdentifier = bundleIdentifier.lowercased()

            for tool in knownTools where matches(tool, name: normalizedName, bundleIdentifier: normalizedBundleIdentifier) {
                let id = bundleIdentifier.isEmpty ? tool.displayName : bundleIdentifier
                guard !seen.contains(id) else { continue }
                seen.insert(id)
                results.append(
                    ConflictingInputTool(
                        id: id,
                        name: name.isEmpty ? tool.displayName : name,
                        bundleIdentifier: bundleIdentifier.isEmpty ? nil : bundleIdentifier
                    )
                )
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func matches(_ tool: KnownTool, name: String, bundleIdentifier: String) -> Bool {
        tool.nameFragments.contains { name.contains($0) }
            || tool.bundleIdentifierFragments.contains { bundleIdentifier.contains($0) }
    }
}

final class ConflictDetectionService {
    private let detector = InputToolConflictDetector()

    func snapshotConflicts() -> [ConflictingInputTool] {
        let applications = NSWorkspace.shared.runningApplications.map {
            RunningApplicationSnapshot(localizedName: $0.localizedName, bundleIdentifier: $0.bundleIdentifier)
        }
        return detector.detect(in: applications)
    }
}
