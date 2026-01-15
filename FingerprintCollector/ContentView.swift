import SwiftUI

struct FingerprintRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let floor: Int
    let label: String
    let uuid: String
    let major: Int
    let minor: Int
    let rssi: Int
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ContentView: View {
    @StateObject private var ranger = BeaconRanger()

    @State private var uuidString = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    @State private var floor: Int = 1

    // New: user label + session records
    @State private var pointLabel: String = "P1"
    @State private var records: [FingerprintRecord] = []

    // New: export UI
    @State private var exportURL: URL?
    @State private var showingShare = false

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

            // New: Point label
            TextField("Point Label (e.g., P12)", text: $pointLabel)
                .textFieldStyle(.roundedBorder)

            // Beacon controls
            HStack {
                Button("Request Permission") { ranger.requestPermission() }
                Button("Start") { ranger.startRanging(uuidString: uuidString) }
                Button("Stop") { ranger.stopRanging() }
            }

            // Capture controls (your existing 15s median capture)
            HStack {
                Button(ranger.isCapturing ? "Capturing \(ranger.secondsLeft)s" : "Capture 15s") {
                    ranger.startCapture(windowSeconds: 15)
                }
                .disabled(ranger.isCapturing)
                .buttonStyle(.borderedProminent)

                Button("Stop Capture") { ranger.stopCapture() }
                    .disabled(!ranger.isCapturing)
            }

            // New: Snapshot + Export controls
            HStack {
                Button("Capture Snapshot") {
                    captureSnapshot()
                }
                .disabled(ranger.live.isEmpty)

                Button("Export CSV") {
                    exportCSV()
                }
                .disabled(records.isEmpty)

                Button("Clear Session") {
                    records.removeAll()
                }
                .disabled(records.isEmpty)
            }

            Text("\(ranger.status)  •  session rows: \(records.count)")
                .foregroundStyle(.secondary)

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
        .sheet(isPresented: $showingShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    // MARK: - Snapshot capture (one row per visible beacon)

    private func captureSnapshot() {
        let now = Date()

        // Take a snapshot of current live RSSI table
        for (id, rssi) in ranger.live {
            records.append(
                FingerprintRecord(
                    timestamp: now,
                    floor: floor,
                    label: pointLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                    uuid: uuidString,
                    major: id.major,
                    minor: id.minor,
                    rssi: rssi
                )
            )
        }
    }

    // MARK: - CSV export

    private func exportCSV() {
        do {
            let csv = makeCSV(records)
            let url = try writeCSVToTempFile(csv: csv)
            exportURL = url
            showingShare = true
        } catch {
            print("Export failed:", error)
        }
    }

    private func makeCSV(_ records: [FingerprintRecord]) -> String {
        var lines: [String] = []
        lines.append("timestamp,floor,label,uuid,major,minor,rssi")

        let iso = ISO8601DateFormatter()
        for r in records {
            let ts = iso.string(from: r.timestamp)
            let safeLabel = r.label.replacingOccurrences(of: ",", with: "_")
            let safeUUID = r.uuid.replacingOccurrences(of: ",", with: "_")
            lines.append("\(ts),\(r.floor),\(safeLabel),\(safeUUID),\(r.major),\(r.minor),\(r.rssi)")
        }
        return lines.joined(separator: "\n")
    }

    private func writeCSVToTempFile(csv: String) throws -> URL {
        let filename = "fingerprints-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard let data = csv.data(using: .utf8) else {
            throw NSError(domain: "CSV", code: 1, userInfo: [NSLocalizedDescriptionKey: "UTF-8 encode failed"])
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}

