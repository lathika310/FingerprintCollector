//
//  FingerprintCollectorView.swift
//  FingerprintCollector
//
//  Created by Lathika on 2026-02-13.
//


import SwiftUI
import UniformTypeIdentifiers

struct FingerprintCollectorView: View {
    @EnvironmentObject private var db: FingerprintDatabase
    @EnvironmentObject private var planStore: FloorPlanStore

    @StateObject private var ranger = BeaconRanger()

    @State private var uuidString = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
    @State private var captureSeconds: Int = 8

    @State private var selectedPlan: FloorPlanID = .eng4North
    @State private var selectedPointID: UUID? = nil

    @State private var records: [FingerprintRecord] = []
    @State private var exportURL: URL?
    @State private var showingShare = false

    @State private var showingImporter = false
    @State private var importError: String?

    private var pointsForPlan: [AnchorPoint] { planStore.points(for: selectedPlan) }

    private var selectedPoint: AnchorPoint? {
        guard let id = selectedPointID else { return nil }
        return pointsForPlan.first(where: { $0.id == id })
    }

    private var liveKeysSorted: [BeaconID] {
        Array(ranger.live.keys).sorted { a, b in
            if a.major != b.major { return a.major < b.major }
            return a.minor < b.minor
        }
    }

    private var medianKeysSorted: [BeaconID] {
        Array(ranger.windowMedians.keys).sorted { a, b in
            if a.major != b.major { return a.major < b.major }
            return a.minor < b.minor
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Fingerprint Collector (Regression)").font(.headline)

            Text(db.status).font(.caption).foregroundStyle(.secondary)

            if let importError {
                Text(importError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Picker("Plan", selection: $selectedPlan) {
                ForEach(FloorPlanID.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if pointsForPlan.isEmpty {
                Text("No points on this plan yet. Go to Plans and add at least one point.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                Picker("Point", selection: Binding(
                    get: { selectedPointID ?? pointsForPlan.first!.id },
                    set: { selectedPointID = $0 }
                )) {
                    ForEach(pointsForPlan) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                let p = selectedPoint ?? pointsForPlan.first!
                Text(String(format: "Selected: %@  (x=%.4f, y=%.4f)", p.name, p.xNorm, p.yNorm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            TextField("Beacon UUID", text: $uuidString)
                .textInputAutocapitalization(.characters)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Stepper(value: $captureSeconds, in: 2...30) {
                Text("Capture Window: \(captureSeconds)s")
            }
            .disabled(ranger.isCapturing)
            .padding(.horizontal)

            HStack {
                Button("Permission") { ranger.requestPermission() }
                Button("Start") { ranger.startRanging(uuidString: uuidString) }
                Button("Stop") { ranger.stopRanging() }
            }

            HStack {
                Button(ranger.isCapturing ? "Capturing \(ranger.secondsLeft)s" : "Capture \(captureSeconds)s") {
                    ranger.startCapture(windowSeconds: captureSeconds)
                }
                .disabled(ranger.isCapturing)
                .buttonStyle(.borderedProminent)

                Button("Stop Capture") { ranger.stopCapture() }
                    .disabled(!ranger.isCapturing)
            }

            HStack {
                Button("Save Medians") { saveMedians() }
                    .disabled(!canSaveMedians)

                Button("Export CSV") { exportCSV() }
                    .disabled(records.isEmpty)

                Button("Clear Session") { records.removeAll() }
                    .disabled(records.isEmpty)
            }

            Divider()

            HStack {
                Button("Import CSV") {
                    importError = nil
                    showingImporter = true
                }
                .buttonStyle(.borderedProminent)

                Button("Clear Dataset") { db.clear() }
                    .buttonStyle(.bordered)
            }

            Text("\(ranger.status) • live: \(ranger.live.count) • saved rows: \(records.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                Section("Live RSSI") {
                    if liveKeysSorted.isEmpty {
                        Text("No live beacons yet. Check UUID + advertiser is on.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(liveKeysSorted, id: \.self) { k in
                            HStack {
                                Text("M\(k.major) m\(k.minor)")
                                Spacer()
                                Text("\(ranger.live[k] ?? 0) dBm")
                            }
                        }
                    }
                }

                Section(ranger.isCapturing ? "Capturing (sample counts)" : "Last medians") {
                    if ranger.isCapturing {
                        ForEach(liveKeysSorted, id: \.self) { k in
                            let count = ranger.captureSampleCounts[k] ?? 0
                            HStack {
                                Text("M\(k.major) m\(k.minor)")
                                Spacer()
                                Text("samples: \(count)").foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        if medianKeysSorted.isEmpty {
                            Text("No medians yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(medianKeysSorted, id: \.self) { k in
                                HStack {
                                    Text("M\(k.major) m\(k.minor)")
                                    Spacer()
                                    Text("\(ranger.windowMedians[k] ?? 0) dBm")
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .onAppear {
            if selectedPointID == nil, let first = pointsForPlan.first { selectedPointID = first.id }
        }
        .onChange(of: selectedPlan) { _, _ in
            selectedPointID = pointsForPlan.first?.id
        }
    }

    private var canSaveMedians: Bool {
        guard !ranger.isCapturing, !ranger.windowMedians.isEmpty else { return false }
        return (selectedPoint != nil) || (pointsForPlan.first != nil)
    }

    private func saveMedians() {
        guard let p = selectedPoint ?? pointsForPlan.first else { return }

        let now = Date()
        let modeTag = "median\(captureSeconds)s"

        for (id, med) in ranger.windowMedians {
            records.append(
                FingerprintRecord(
                    timestamp: now,
                    planID: selectedPlan.rawValue,
                    pointID: p.id.uuidString,
                    pointName: p.name,
                    xNorm: p.xNorm,
                    yNorm: p.yNorm,
                    uuid: uuidString,
                    major: id.major,
                    minor: id.minor,
                    rssi: med,
                    mode: modeTag
                )
            )
        }
    }

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
        lines.append("timestamp,planID,pointID,pointName,xNorm,yNorm,uuid,major,minor,rssi,mode")

        let iso = ISO8601DateFormatter()
        for r in records {
            let ts = iso.string(from: r.timestamp)
            lines.append("\(ts),\(r.planID),\(r.pointID),\(r.pointName),\(r.xNorm),\(r.yNorm),\(r.uuid),\(r.major),\(r.minor),\(r.rssi),\(r.mode)")
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

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            importError = "Import failed"
            db.status = "Import failed"

        case .success(let urls):
            guard let url = urls.first else { return }
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                try buildDatabase(fromCSVText: text)
            } catch {
                importError = "CSV parse error"
                db.status = "Parse error"
            }
        }
    }

    // Builds regression training samples: one sample per timestamp (median vector + x/y)
    private func buildDatabase(fromCSVText text: String) throws {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 2 else { return }

        let header = lines[0].split(separator: ",").map(String.init)
        func idx(_ name: String) -> Int? { header.firstIndex(of: name) }

        guard
            let tsI = idx("timestamp"),
            let planI = idx("planID"),
            let xI = idx("xNorm"),
            let yI = idx("yNorm"),
            let majorI = idx("major"),
            let minorI = idx("minor"),
            let rssiI = idx("rssi")
        else { return }

        let modeI = idx("mode")

        struct Key: Hashable {
            let ts: String
            let plan: String
            let x: Double
            let y: Double
        }

        var beaconSet: Set<String> = []
        var grouped: [Key: [String: [Int]]] = [:]

        for row in lines.dropFirst() {
            let parts = row.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            if parts.count < header.count { continue }

            if let modeI {
                let mode = parts[modeI]
                if !mode.hasPrefix("median") { continue }
            }

            let ts = parts[tsI]
            let plan = parts[planI]
            let x = Double(parts[xI]) ?? 0.0
            let y = Double(parts[yI]) ?? 0.0

            let beacon = "\(parts[majorI])_\(parts[minorI])"
            beaconSet.insert(beacon)

            let rssi = Int(parts[rssiI]) ?? -100

            let k = Key(ts: ts, plan: plan, x: x, y: y)
            grouped[k, default: [:]][beacon, default: []].append(rssi)
        }

        let beacons = beaconSet.sorted()
        if beacons.isEmpty || grouped.isEmpty {
            db.beacons = []
            db.samples = []
            db.status = "No median rows found"
            importError = "No median rows found"
            return
        }

        let index = Dictionary(uniqueKeysWithValues: beacons.enumerated().map { ($0.element, $0.offset) })
        let RSSI_FLOOR = -100.0

        func medianInt(_ vals: [Int]) -> Int {
            let s = vals.sorted()
            let m = s.count / 2
            if s.count % 2 == 0 { return Int(Double(s[m-1] + s[m]) / 2.0) }
            return s[m]
        }

        var samples: [FingerprintSample] = []
        for (k, beaconMap) in grouped {
            var vec = Array(repeating: RSSI_FLOOR, count: beacons.count)
            for (b, vals) in beaconMap {
                if let i = index[b] {
                    vec[i] = Double(medianInt(vals))
                }
            }
            samples.append(FingerprintSample(planID: k.plan, xNorm: k.x, yNorm: k.y, vector: vec))
        }

        db.beacons = beacons
        db.samples = samples
        db.status = "Imported \(samples.count) samples, \(beacons.count) beacons"
        importError = nil
        db.save()
    }
}
