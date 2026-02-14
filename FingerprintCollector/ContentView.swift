import SwiftUI

struct ContentView: View {
    @StateObject private var db = FingerprintDatabase()
    @StateObject private var planStore = FloorPlanStore()

    var body: some View {
        TabView {
            FingerprintCollectorView()
                .environmentObject(db)
                .environmentObject(planStore)
                .tabItem {
                    Image(systemName: "wave.3.right")
                    Text("Collect")
                }

            RegressionLiveMapView()
                .environmentObject(db)
                .tabItem {
                    Image(systemName: "location.fill")
                    Text("Live")
                }

            FloorPlanEditorView()
                .environmentObject(planStore)
                .tabItem {
                    Image(systemName: "pencil.and.outline")
                    Text("Plans")
                }
        }
    }
}

