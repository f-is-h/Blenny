import AppKit
import BlennyCore
import SwiftUI

func debugAccessibilityFlag(_ key: String) -> Bool {
    #if DEBUG
    DebugAccessibilityEnvironment.values[key] == "YES"
    #else
    false
    #endif
}

#if DEBUG
enum DebugAccessibilityEnvironment {
    // A process environment cannot change after launch. Reading and bridging
    // the full Foundation environment from every Board item makes SwiftUI's
    // view-update hot path unnecessarily expensive.
    static let values = ProcessInfo.processInfo.environment
}
#endif

enum BlennyDesign {
    static let navigationHeight: CGFloat = 54
    static let boardRadius: CGFloat = 10
    static let laneHeight: CGFloat = 60
    static let iconFrame: CGFloat = 34
    static let itemFrame = CGSize(width: 48, height: 50)
    static let itemChromeFrame = CGSize(width: 40, height: 40)

    static let coral = Color(nsColor: NSColor(
        name: NSColor.Name("BlennyCoral")
    ) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 1.00, green: 0.46, blue: 0.42, alpha: 1)
            : NSColor(srgbRed: 0.94, green: 0.36, blue: 0.33, alpha: 1)
    })
}

struct ProductNavigationBar: View {
    let selection: ProductInterfaceSection
    let onSelect: (ProductInterfaceSection) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast


    var body: some View {
        HStack(spacing: navigationItemSpacing) {
            ForEach(ProductInterfaceSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(navigationAnimation) {
                        onSelect(section)
                    }
                } label: {
                    navigationLabel(section)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .foregroundStyle(
                    selection == section ? Color.primary : Color.secondary
                )
                .accessibilityValue(
                    selection == section ? "Selected" : "Not selected"
                )
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(navigationTrackPadding)
        .background { navigationTrack }
        .frame(maxWidth: .infinity)
        .frame(height: BlennyDesign.navigationHeight)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Blenny section")
    }

    private var navigationTrack: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(
                    effectiveReduceTransparency
                        ? Color(nsColor: .controlBackgroundColor)
                        : Color.primary.opacity(0.045)
                )

            selectionLens
                .offset(x: selectionLensOffset)
                .animation(navigationAnimation, value: selection)
        }
        .overlay {
            Capsule().stroke(
                Color(nsColor: .separatorColor).opacity(
                    effectiveContrast == .increased ? 0.9 : 0.45
                ),
                lineWidth: effectiveContrast == .increased ? 1.25 : 0.5
            )
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var selectionLens: some View {
        if effectiveReduceTransparency {
            Capsule()
                .fill(Color.accentColor.opacity(
                    effectiveContrast == .increased ? 0.16 : 0.08
                ))
                .overlay {
                    if effectiveContrast == .increased {
                        Capsule().stroke(Color.accentColor, lineWidth: 1.25)
                    }
                }
                .frame(width: navigationItemWidth, height: navigationItemHeight)
        } else {
            GlassEffectContainer(spacing: 0) {
                Color.clear
                    .frame(width: navigationItemWidth, height: navigationItemHeight)
                    .glassEffect(
                        .regular
                            .tint(Color.accentColor.opacity(
                                effectiveContrast == .increased ? 0.16 : 0.09
                            )),
                        in: Capsule()
                    )
            }
            .frame(width: navigationItemWidth, height: navigationItemHeight)
            .allowsHitTesting(false)
        }
    }

    private func navigationLabel(
        _ section: ProductInterfaceSection
    ) -> some View {
        Label(section.title, systemImage: section.symbolName)
            .font(
                .system(
                    .callout,
                    design: .default,
                    weight: selection == section ? .medium : .regular
                )
            )
            .frame(width: navigationItemWidth, height: navigationItemHeight)
            .contentShape(Capsule())
    }

    private var selectionLensOffset: CGFloat {
        let index = ProductInterfaceSection.allCases.firstIndex(of: selection) ?? 0
        return navigationTrackPadding
            + CGFloat(index) * (navigationItemWidth + navigationItemSpacing)
    }

    private var navigationItemWidth: CGFloat { 112 }
    private var navigationItemHeight: CGFloat { 28 }
    private var navigationItemSpacing: CGFloat { 4 }
    private var navigationTrackPadding: CGFloat { 5 }

    private var navigationAnimation: Animation {
        effectiveReduceMotion
            ? .easeOut(duration: 0.08)
            : .spring(duration: 0.30, bounce: 0.06)
    }

    private var effectiveReduceMotion: Bool {
        reduceMotion || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_MOTION")
    }

    private var effectiveReduceTransparency: Bool {
        reduceTransparency
            || debugAccessibilityFlag("BLENNY_VALIDATE_REDUCE_TRANSPARENCY")
    }

    private var effectiveContrast: ColorSchemeContrast {
        debugAccessibilityFlag("BLENNY_VALIDATE_INCREASE_CONTRAST")
            ? .increased
            : contrast
    }
}
