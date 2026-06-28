import SwiftUI

@main
struct GymSwipeIOSApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Color(hex: "5e910e"))
        }
    }
}
