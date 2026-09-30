import AppKit
import BlennyCore
import SwiftUI

struct SupportView: View {
    let actions: ProductInterfaceActions

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                ProductPageHeader(
                    title: "Support",
                    subtitle: "Project information and support."
                )

                HStack(alignment: .center, spacing: 15) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .accessibilityLabel("Blenny application icon")
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Blenny")
                            .font(.system(.title2, design: .rounded, weight: .medium))
                        Text("Version \(applicationVersion) · A quiet home for menu bar icons.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button(action: actions.openProjectWebsite) {
                            Label("Website", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                        Text("If Blenny is useful to you, help support its development.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 12) {
                            Button(action: actions.openOneTimeSponsor) {
                                Label("Sponsor once", systemImage: "heart")
                            }
                            Button(action: actions.openMonthlySponsor) {
                                Label("Sponsor monthly", systemImage: "heart.fill")
                            }
                            Button(action: actions.openKoFi) {
                                Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Link(destination: URL(string: ProductSupportLinks.documentation)!) {
                Label("Help & Documentation", systemImage: "arrow.up.right.square")
            }
            .font(.callout)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var applicationVersion: String {
        BlennyApplicationVersion.display
    }
}
