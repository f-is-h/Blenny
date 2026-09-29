/// Presentation only. Recovery and mutation authority remain with the existing writer.
public struct StatusMenuVisibility: Equatable, Sendable {
    public let showsResume: Bool
    public let showsStop: Bool
    public let showsRestore: Bool

    public init(state: ManagementLoopState, persistedManagementEnabled: Bool, recoveryAvailable: Bool) {
        // A paused saved session needs both Resume and Stop: Stop clears saved intent.
        showsResume = state.canResume || !persistedManagementEnabled
        showsStop = persistedManagementEnabled
        showsRestore = recoveryAvailable
    }
}
