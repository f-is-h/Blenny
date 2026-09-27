import Foundation

/// A presentation name is never authority for a system write. Resolve only a
/// single, owner-attributed observation to an existing exact writer target.
public enum SystemItemCapabilityIdentity {
    public static func policyIdentifier(
        for observation: SystemMenuBarItemObservation,
        retainedWhileAbsent: Bool = false
    ) -> String? {
        guard observation.observationCount == 1
                || (observation.observationCount == 0 && retainedWhileAbsent) else {
            return nil
        }
        if let item = SystemItemPolicyCatalog.controllableItem(
            for: observation.observationIdentifier
        ) {
            // MenuBarAgent can report the exact AX identifier for a shared
            // Control Center module. It is also the owner of retained rows.
            guard observation.ownerBundleIdentifier == "com.apple.controlcenter"
                    || observation.ownerBundleIdentifier == "com.apple.MenuBarAgent" else {
                return nil
            }
            return item.identifier
        }
        guard let item = PersistentSystemItemPolicyCatalog.controllableItem(
            forObservationIdentifier: observation.observationIdentifier
        ), let target = SharedSystemItemTrialTarget.allCases.first(where: {
            $0.observationIdentifier == item.identifier
        }) else {
            return nil
        }
        let directHost = observation.ownerBundleIdentifier
            == target.ownerBundleIdentifier
        let exactAgentItem = observation.ownerBundleIdentifier
            == "com.apple.MenuBarAgent"
            && observation.observationIdentifier == item.identifier
        guard directHost || exactAgentItem else { return nil }
        return item.identifier
    }

    #if DEBUG
    public static func orderingItem(
        for observation: SystemMenuBarItemObservation,
        retainedWhileAbsent: Bool = false
    ) -> ExactSystemOrderingItem? {
        guard let identifier = policyIdentifier(
            for: observation, retainedWhileAbsent: retainedWhileAbsent
        ) else { return nil }
        return ExactSystemOrderingItem.allCases.first {
            $0.observationIdentifier == identifier
        }
    }
    #endif
}
