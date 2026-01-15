import SwiftUI

struct ContentView: View {
    @StateObject private var ranger = BeaconRanger()

    @State private var uuidString = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    @State private var floor: Int = 1

    private var allKnownKeysSorted: [BeaconID] {
        let all = Set(ranger.live.keys)
            .union(ranger.captureSampleCounts.keys)
            .union(ranger.windowMedians.keys)
        return Array(all).sorted { a, b in
            if a.major != b.major { return a.major < b.major }
            return a.minor < b.minor
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Fingerprint Collector").font(.headline)

            // Floor input
            Stepper(value: $floor, in: 0...20) {
                Text("Floor: \(floor)")
            }

            // Beacon UUID
            TextField("Beacon UUID", text: $uuidString)
                .textInputAutocapitalization(.characters)
                .textFieldStyle(.roundedBorder)

            // Beacon controls
            HStack {
                Button("Request Permission") { ranger.requestPermission() }
                Button("Start") { ranger.startRanging(uuidString: uuidString) }
                Button("Stop") { ranger.stopRanging() }
            }

            // Capture controls
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

            Text("Beacon Stats").font(.subheadline)

            List {
                ForEach(allKnownKeysSorted, id: \.self) { k in
                    let liveRssi = ranger.live[k]
                    let count = ranger.captureSampleCounts[k] ?? 0
                    let med = ranger.windowMedians[k]
                    let isDiscarded = ranger.isBeaconDiscarded(k)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("M\(k.major) m\(k.minor)")
                                .fontWeight(.semibold)

                            if isDiscarded {
                                Text("DISCARDED (offline > 3s)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else if ranger.isCapturing {
                                Text("samples: \(count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let med {
                                Text("median: \(med) dBm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(liveRssi != nil ? "\(liveRssi!) dBm" : "—")
                            .foregroundStyle(liveRssi != nil ? .primary : .secondary)
                    }
                }
            }
        }
        .padding()
    }
}

