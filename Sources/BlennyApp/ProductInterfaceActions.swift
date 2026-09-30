import AppKit
import BlennyCore
import Combine
import QuartzCore
import SwiftUI

@MainActor
struct ProductInterfaceActions {
    let refresh: () -> Void
    let requestAccess: () -> Void
    let resumeManaging: () -> Void
    let stopManaging: () -> Void
    let restorePreviousPolicy: () -> Void
    let draftDidChange: (PolicyEditorViewModel) -> Void
    let applyDraft: () -> Void
    let openProjectWebsite: () -> Void
    let openMonthlySponsor: () -> Void
    let openOneTimeSponsor: () -> Void
    let openKoFi: () -> Void
    let setLaunchAtLogin: (Bool) -> Void
    let openLoginItemsSettings: () -> Void
    let checkForUpdates: (() -> Void)?
    var setAutomaticUpdateChecks: ((Bool) -> Void)? = nil
    let showFishPlacementGuide: () -> Void
    let hideSharedSystemItem: (SharedSystemItemTrialTarget) -> Void
    let restoreSharedSystemItem: (SharedSystemItemTrialTarget) -> Void
}

#if BLENNY_PRODUCT || DEBUG || BLENNY_SHARED_SYSTEM_ITEM_TRIAL
enum SharedSystemItemTrialPresentation: Equatable {
    case checking
    case ready
    case hidden
    case busy
    case recoveryRequired
    case unavailable(String)
}
#endif

struct ResolvedPolicyIcon {
    let descriptor: PolicyIconDescriptor
    let displayName: String
    let image: NSImage
}

#if BLENNY_PRODUCT || DEBUG
enum OrderingBoardConfigurationMutationOutcome {
    case changed(policyChanged: Bool)
    case unchanged
    case rejected(String)
}
#endif

@MainActor
final class WorkspacePolicyIconResolver {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func applicationIcon(bundleIdentifier: String) -> ResolvedPolicyIcon {
        let semanticDescriptor = PolicyIconResolver.applicationDescriptor(
            bundleIdentifier: bundleIdentifier,
            installedApplicationResolved: false
        )
        if let displayName = ExperimentalAppleBundlePolicyCatalog.displayName(
            for: bundleIdentifier
        ), let symbolName = semanticDescriptor.symbolName,
           let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: displayName
           ) {
            return ResolvedPolicyIcon(
                descriptor: semanticDescriptor,
                displayName: displayName,
                image: sizedCopy(of: image)
            )
        }
        guard let applicationURL = workspace.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return fallback(displayName: fallbackDisplayName(for: bundleIdentifier))
        }

        let applicationBundle = Bundle(url: applicationURL)
        let displayName = applicationBundle?
            .object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? applicationBundle?
                .object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? FileManager.default.displayName(atPath: applicationURL.path)
        guard applicationBundle.flatMap(\.bundleIdentifier).flatMap({
            BundlePolicyIdentity.canonicalKey(for: $0)
        }) == BundlePolicyIdentity.canonicalKey(for: bundleIdentifier),
              applicationBundle.map(hasDeclaredApplicationIcon) == true else {
            return fallback(displayName: displayName)
        }
        let workspaceImage = workspace.icon(forFile: applicationURL.path)
        guard workspaceImage.isValid, !workspaceImage.representations.isEmpty else {
            return fallback(displayName: displayName)
        }
        return ResolvedPolicyIcon(
            descriptor: PolicyIconResolver.applicationDescriptor(
                bundleIdentifier: bundleIdentifier,
                installedApplicationResolved: true
            ),
            displayName: displayName,
            image: sizedCopy(of: workspaceImage)
        )
    }

    func systemIcon(observation: SystemMenuBarItemObservation) -> ResolvedPolicyIcon {
        let descriptor = PolicyIconResolver.systemItemDescriptor(
            observationIdentifier: observation.observationIdentifier
        )
        let image: NSImage?
        if let symbolName = descriptor.symbolName {
            image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: observation.displayName
            )
        } else if let namedImageName = descriptor.namedImageName {
            image = NSImage(named: NSImage.Name(namedImageName))
        } else {
            image = nil
        }
        guard let image else {
            return fallback(displayName: observation.displayName)
        }
        return ResolvedPolicyIcon(
            descriptor: descriptor,
            displayName: observation.displayName,
            image: sizedCopy(of: image)
        )
    }

    private func fallback(displayName: String) -> ResolvedPolicyIcon {
        let image = NSImage(
            systemSymbolName: PolicyIconDescriptor.fallbackSymbolName,
            accessibilityDescription: "Unknown item icon"
        ) ?? NSImage(size: NSSize(width: 38, height: 38))
        return ResolvedPolicyIcon(
            descriptor: .fallback,
            displayName: displayName,
            image: sizedCopy(of: image)
        )
    }

    private func fallbackDisplayName(for bundleIdentifier: String) -> String {
        bundleIdentifier.split(separator: ".").last.map(String.init) ?? bundleIdentifier
    }

    private func hasDeclaredApplicationIcon(_ bundle: Bundle) -> Bool {
        let stringKeys = ["CFBundleIconName", "CFBundleIconFile"]
        if stringKeys.contains(where: {
            (bundle.object(forInfoDictionaryKey: $0) as? String)?.isEmpty == false
        }) {
            return true
        }
        if let iconFiles = bundle.object(forInfoDictionaryKey: "CFBundleIconFiles")
            as? [String], !iconFiles.isEmpty {
            return true
        }
        if let icons = bundle.object(forInfoDictionaryKey: "CFBundleIcons")
            as? [String: Any], !icons.isEmpty {
            return true
        }
        return false
    }

    private func sizedCopy(of image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: 38, height: 38)
        return copy
    }
}
