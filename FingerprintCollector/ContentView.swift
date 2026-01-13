import SwiftUI

struct ContentView: View {
    @StateObject private var ranger = BeaconRanger()
    @State private var uuidString = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

    private var sortedLiveKeys: [BeaconID] {
        Array(ranger.live.keys).sorted { a, b in
            if a.major != b.major { return a.major < b.major }
            return a.minor < b.minor
        }
    }

    private var sortedMedianKeys: [BeaconID] {
        Array(ranger.windowMedians.keys).sorted { a, b in
            if a.major != b.major { return a.major < b.major }
            return a.minor < b.minor
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("iBeacon Fingerprint Capture").font(.headline)

            TextField("Beacon UUID", text: $uuidString)
                .textInputAutocapitalization(.characters)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Request Permission") { ranger.requestPermission() }
                Button("Start") { ranger.startRanging(uuidString: uuidString) }
                Button("Stop") { ranger.stopRanging() }
            }

            HStack {
                Button(ranger.isCapturing ? "Capturing \(ranger.secondsLeft)s" : "Capture 15s") {
                    ranger.startCapture(windowSeconds: 15)
                }
                .disabled(ranger.isCapturing)
                .buttonStyle(.borderedProminent)

                Button("Stop Capture") { ranger.stopCapture() }
                    .disabled(!ranger.isCapturing)
            }

            Text(ranger.status).foregroundStyle(.secondary)

            Divider()

            Text("Live RSSI (latest):").font(.subheadline)
            List {
                ForEach(sortedLiveKeys, id: \.self) { k in
                    HStack {
                        Text("M\(k.major) m\(k.minor)")
                        Spacer()
                        Text("\(ranger.live[k] ?? 0) dBm")
                    }
                }
            }
            .frame(maxHeight: 220)

            Text("Window Medians (offline beacons discarded):").font(.subheadline)
            List {
                ForEach(sortedMedianKeys, id: \.self) { k in
                    HStack {
                        Text("M\(k.major) m\(k.minor)")
                        Spacer()
                        Text("\(ranger.windowMedians[k] ?? 0) dBm (median)")
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding()
    }
}

