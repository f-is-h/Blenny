public enum StatusItemControl: String, Sendable {
    case arrow
    case artwork
}

public enum StatusItemClickAction: String, Equatable, Sendable {
    case toggleReveal
    case openEditor
    case openMenu
    case ignore
}

public enum StatusItemClickRouting {
    /// The native sender identifies the action. No event coordinates or nested
    /// child hit testing are used to distinguish the two controls.
    public static func action(
        control: StatusItemControl,
        isSecondaryClick: Bool, canToggleReveal: Bool
    ) -> StatusItemClickAction {
        if isSecondaryClick { return .openMenu }
        if control == .arrow {
            return canToggleReveal ? .toggleReveal : .ignore
        }
        return .openEditor
    }
}
