import Foundation

public enum UpdateInteractionPolicy {
    public static func allowsCheck(hasDraft: Bool, isBusy: Bool, recoveryPending: Bool) -> Bool {
        !hasDraft && !isBusy && !recoveryPending
    }
}
