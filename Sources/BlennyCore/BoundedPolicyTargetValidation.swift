import Foundation

public struct MenuBarPolicyTargetObservation: Equatable, Sendable {
    public let bundleIdentifier: String
    public let processIdentifiers: [Int32]
    public let menuBarItemCount: Int

    public init(
        bundleIdentifier: String,
        processIdentifiers: [Int32],
        menuBarItemCount: Int
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifiers = Array(Set(processIdentifiers)).sorted()
        self.menuBarItemCount = menuBarItemCount
    }
}

public enum BoundedPolicyTargetValidationError: Error, Equatable, Sendable {
    case assignmentMismatch
    case missingObservation(bundleIdentifier: String)
    case duplicateObservation(bundleIdentifier: String)
    case ambiguousProcessOwnership(bundleIdentifier: String, processCount: Int)
    case missingMenuBarOwnership(bundleIdentifier: String)
}

public enum BoundedPolicyTargetValidator {
    public static func validate(
        assignments: BundlePolicyAssignments,
        pinnedBundleIdentifier: String,
        revealableBundleIdentifier: String,
        hiddenBundleIdentifier: String,
        observations: [MenuBarPolicyTargetObservation]
    ) throws {
        guard assignments.pinned == [pinnedBundleIdentifier],
            assignments.revealable == [revealableBundleIdentifier],
            assignments.hidden == [hiddenBundleIdentifier]
        else {
            throw BoundedPolicyTargetValidationError.assignmentMismatch
        }

        let grouped = Dictionary(grouping: observations, by: \.bundleIdentifier)
        for bundleIdentifier in [revealableBundleIdentifier, hiddenBundleIdentifier] {
            guard let matching = grouped[bundleIdentifier] else {
                throw BoundedPolicyTargetValidationError.missingObservation(
                    bundleIdentifier: bundleIdentifier
                )
            }
            guard matching.count == 1, let observation = matching.first else {
                throw BoundedPolicyTargetValidationError.duplicateObservation(
                    bundleIdentifier: bundleIdentifier
                )
            }
            guard observation.processIdentifiers.count == 1 else {
                throw BoundedPolicyTargetValidationError.ambiguousProcessOwnership(
                    bundleIdentifier: bundleIdentifier,
                    processCount: observation.processIdentifiers.count
                )
            }
            guard observation.menuBarItemCount > 0 else {
                throw BoundedPolicyTargetValidationError.missingMenuBarOwnership(
                    bundleIdentifier: bundleIdentifier
                )
            }
        }
    }
}
