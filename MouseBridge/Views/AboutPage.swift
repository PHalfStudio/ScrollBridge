import AppKit
import SwiftUI

struct AboutPage: View {
    @EnvironmentObject private var appState: AppState
    private let metadata = AppAboutMetadata.current
    private let toolbarSafeAreaTopPadding: CGFloat

    init(toolbarSafeAreaTopPadding: CGFloat = 0) {
        self.toolbarSafeAreaTopPadding = toolbarSafeAreaTopPadding
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityLabel(Text("about.appIcon"))
                Text("app.name")
                    .font(.largeTitle.weight(.semibold))
                Text(metadata.versionDisplay)
                    .foregroundStyle(.secondary)
                Text("about.privacy")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    infoRow("about.version", metadata.versionDisplay)
                    infoRow("about.build", metadata.build)
                    infoRow("about.gitCommit", metadata.gitCommit)
                    infoRow("about.copyright", metadata.copyright)
                    linkInfoRow("about.openSourceLicense", metadata.licenseFileName, urlString: "https://sites.phalfstudio.cn/scroll-bridge-license")
                    linkInfoRow("about.privacyPolicy", metadata.privacyFileName, urlString: "https://sites.phalfstudio.cn/scroll-bridge-privacy")
                    linkInfoRow("about.github", "MouseBridge", urlString: "https://github.com/PHalfStudio/MouseBridge/releases/latest")
                    infoRow("about.updateStatus", LocalizedStringKey(appState.updateStatus.titleKey))
                    HStack {
                        Spacer()
                        Button("about.checkForUpdates") {
                            appState.checkForUpdatesManually()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint(Text("about.checkForUpdates.hint"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Label("about.localOnly", systemImage: "lock.shield")
                    Label("about.noClipboard", systemImage: "doc.on.clipboard")
                    Label("about.compatibility", systemImage: "exclamationmark.triangle")
                    Text("about.references")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(28)
        }
        .navigationTitle("page.about")
    }

    private func infoRow(_ titleKey: LocalizedStringKey, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.callout)
    }

    private func infoRow(_ titleKey: LocalizedStringKey, _ valueKey: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
            Spacer()
            Text(valueKey)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private func linkInfoRow(_ titleKey: LocalizedStringKey, _ value: String, urlString: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
            Spacer()
            Link(value, destination: URL(string: urlString)!)
                .foregroundStyle(.link)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}
