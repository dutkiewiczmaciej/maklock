import SwiftUI

/// SwiftUI content for the menu bar popover dropdown.
struct MenuBarView: View {
    let onSettingsClicked: () -> Void
    let onQuitClicked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MakLockColors.gold)
                Text("MakLock")
                    .font(MakLockTypography.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 8)

            // Status
            HStack {
                Circle()
                    .fill(MakLockColors.success)
                    .frame(width: 8, height: 8)
                Text("Protection Active")
                    .font(MakLockTypography.body)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 8)

            // Actions
            MenuBarButton(title: "Settings...", icon: "gearshape") {
                onSettingsClicked()
            }

            Divider()
                .padding(.horizontal, 8)

            MenuBarButton(title: "Quit MakLock", icon: "power") {
                onQuitClicked()
            }

            Spacer()
                .frame(height: 8)
        }
        .frame(width: 260)
    }
}

// MARK: - Menu Bar Button

private struct MenuBarButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(MakLockTypography.body)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
