import SwiftUI

struct ContentView: View {
    @StateObject private var ranger = BeaconRanger()
    @State private var uuidString = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    
    private var sortedKeys: [BeaconID] {
        Array(ranger.live.keys).sorted { a, b in
            if a.major != b.major { return a.major < b.major }
            return a.minor < b.minor
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("iBeacon Ranging Test").font(.headline)
            
            TextField("Beacon UUID", text: $uuidString)
                .textInputAutocapitalization(.characters)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Request Permission") { ranger.requestPermission() }
                Button("Start") { ranger.startRanging(uuidString: uuidString) }
                Button("Stop") { ranger.stopRanging() }
            }
            
            Text(ranger.status).foregroundStyle(.secondary)
            
            List {
                ForEach(sortedKeys, id: \.self) { k in
                    HStack {
                        Text("Major \(k.major)  Minor \(k.minor)")
                        Spacer()
                        Text("\(ranger.live[k] ?? 0) dBm")
                    }
                }
            }
        }
        .padding()
    }
}

