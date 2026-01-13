import SwiftUI

struct ContentView: View {
    @StateObject private var ranger = BeaconRanger()
    @State private var uuidString = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

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

            Text("Beacon Stats").font(.subheadline)

            List {
                ForEach(allKnownKeysSorted, id: \.self) { k in
                    let liveRssi = ranger.live[k]
                    let count = ranger.captureSampleCounts[k] ?? 0
                    let med = ranger.windowMedians[k]
                    let discarded = ranger.isBeaconDiscarded(k)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("M\(k.major) m\(k.minor)")
                                .fontWeight(.semibold)

                            if discarded {
                                Text("DISCARDED (offline > 3s)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else if ranger.isCapturing {
                                Text("samples: \(count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let med {
                                Text("median: \(med) dBm (n=\(count == 0 ? (ranger.captureSampleCounts[k] ?? 0) : count))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(liveRssi != nil ? "\(liveRssi!) dBm" : "—")
                                .foregroundStyle(liveRssi != nil ? .primary : .secondary)

                            if let med {
                                Text("med \(med)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

