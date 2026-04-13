import SwiftUI

/// Main entry point for Mom Alarm Clock.
/// Uses role-based navigation: on first launch the user picks Parent or Child mode,
/// then the app presents the appropriate root view for all subsequent launches.
@main
struct MomAlarmClockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("selectedRole") private var selectedRole: String = ""
    @State private var parentVM = ParentViewModel()
    @State private var childVM = ChildViewModel()

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch selectedRole {
        case "parent":
            ParentDashboardView()
                .environment(parentVM)
        case "child":
            ChildAlarmView()
                .environment(childVM)
        default:
            RoleSelectionView(selectedRole: $selectedRole)
        }
    }
}
