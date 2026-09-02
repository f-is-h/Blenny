import Testing
@testable import BlennyCore

@Suite("Display configuration lifecycle evidence")
struct DisplayConfigurationPolicyTests {
    private let builtIn = DisplayConfigurationRecord(
        displayIdentifier: 1,
        frameX: 0,
        frameY: 0,
        frameWidth: 1600,
        frameHeight: 900,
        backingScaleFactor: 2
    )
    private let external = DisplayConfigurationRecord(
        displayIdentifier: 2,
        frameX: 1600,
        frameY: 0,
        frameWidth: 1920,
        frameHeight: 1080,
        backingScaleFactor: 1
    )

    @Test("A notification without a physical display change keeps management active")
    func unchangedSignatureDoesNotInvalidate() {
        let previous = DisplayConfigurationSignature(displays: [builtIn, external])
        let reordered = DisplayConfigurationSignature(displays: [external, builtIn])

        #expect(!DisplayConfigurationPolicy.invalidates(
            previous: previous, current: reordered
        ))
    }

    @Test("Display identity, geometry and scale changes invalidate", arguments: [
        DisplayConfigurationRecord(
            displayIdentifier: 3, frameX: 0, frameY: 0,
            frameWidth: 1600, frameHeight: 900, backingScaleFactor: 2
        ),
        DisplayConfigurationRecord(
            displayIdentifier: 1, frameX: 0, frameY: 0,
            frameWidth: 1728, frameHeight: 1117, backingScaleFactor: 2
        ),
        DisplayConfigurationRecord(
            displayIdentifier: 1, frameX: 0, frameY: 0,
            frameWidth: 1600, frameHeight: 900, backingScaleFactor: 1
        ),
    ])
    func realDisplayChangesInvalidate(_ changed: DisplayConfigurationRecord) {
        let previous = DisplayConfigurationSignature(displays: [builtIn])
        let current = DisplayConfigurationSignature(displays: [changed])

        #expect(DisplayConfigurationPolicy.invalidates(
            previous: previous, current: current
        ))
    }
}
