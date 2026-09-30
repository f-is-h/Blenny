import AppKit
import BlennyCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: ProductInterfaceModel
    let actions: ProductInterfaceActions

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                ProductPageHeader(
                    title: "Settings",
                    subtitle: "Permissions, startup, and updates."
                )

            ProductPageSection(title: "Permission", systemImage: "hand.raised", spacing: 5) {
                SettingsGridRow {
                    Label(
                        model.accessibilityTrusted
                            ? "Device Control granted"
                            : "Device Control not granted",
                        systemImage: model.accessibilityTrusted
                            ? "checkmark.shield.fill"
                            : "exclamationmark.shield.fill"
                    )
                    .foregroundStyle(model.accessibilityTrusted ? .green : .orange)
                } detail: {
                    Text(permissionDescription)
                } control: {
                    if !model.accessibilityTrusted {
                        Button(permissionButtonTitle, action: actions.requestAccess)
                            .controlSize(.small)
                    }
                }
            }

            ProductPageSection(title: "Startup", systemImage: "power", spacing: 5) {
                SettingsGridRow {
                    Text("Open at Login")
                } detail: {
                    Text(model.launchAtLoginState.statusDescription)
                        .foregroundStyle(
                            model.launchAtLoginState.failureMessage == nil
                                ? Color.secondary
                                : Color.red
                        )
                } control: {
                    HStack(spacing: 8) {
                        if model.launchAtLoginState.requiresApproval {
                            Button("Open Login Items", action: actions.openLoginItemsSettings)
                                .controlSize(.small)
                        }
                        Toggle(
                            "Open Blenny at Login",
                            isOn: Binding(
                                get: { model.launchAtLoginState.isToggleOn },
                                set: { enabled in
                                    actions.setLaunchAtLogin(enabled)
                                }
                            )
                        )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityLabel("Open Blenny at Login")
                        .accessibilityValue(
                            model.launchAtLoginState.isToggleOn ? "On" : "Off"
                        )
                    }
                }
            }

            ProductPageSection(title: "Updates", systemImage: "arrow.triangle.2.circlepath", spacing: 5) {
                SettingsGridRow {
                    Text("Software Updates")
                } detail: {
                    Text(actions.checkForUpdates == nil
                         ? "An update feed is not configured for this build."
                         : "Signed updates. Choose automatic checks or check now.")
                        .foregroundStyle(.secondary)
                } control: {
                    if let checkForUpdates = actions.checkForUpdates {
                        VStack(alignment: .trailing, spacing: 4) {
                            Button("Check for Updates", action: checkForUpdates)
                                .controlSize(.small)
                            if let setChecks = actions.setAutomaticUpdateChecks {
                                Toggle("Automatic checks", isOn: Binding(
                                    get: { model.automaticUpdateChecks },
                                    set: { setChecks($0) }
                                ))
                                .toggleStyle(.checkbox)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }

            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var permissionDescription: String {
        if model.accessibilityTrusted {
            return "Allows Blenny to identify menu bar items and observe the overflow control."
        }
        if model.accessibilityPromptRequested {
            return "Turn on Blenny in Device Control and Data Access, then return here."
        }
        return "macOS grants broad control access. Blenny uses it for menu bar management."
    }

    private var permissionButtonTitle: String {
        model.accessibilityPromptRequested ? "Open System Settings" : "Set Up Access…"
    }

}
