//
//  LiveKNNRegressor.swift
//  FingerprintCollector
//
//  Created by Lathika on 2026-02-13.
//


import Foundation
import Combine

final class LiveKNNRegressor: ObservableObject {
    @Published var xNorm: Double? = nil
    @Published var yNorm: Double? = nil
    @Published var status: String = "Idle"
    @Published var confidence: Double = 0.0

    let ranger = BeaconRanger()

    var k: Int = 5
    var rssiFloor: Double = -100.0
    var updateHz: Double = 1.0
    var emaAlpha: Double = 0.35

    private var timerCancellable: AnyCancellable?
    private var db: FingerprintDatabase?

    private var beacons: [String] = []
    private var trainX: [[Double]] = []
    private var trainXY: [(x: Double, y: Double)] = []
    private var mean: [Double] = []
    private var std: [Double] = []
    private var lastEMA: (x: Double, y: Double)?

    func attachDatabase(_ db: FingerprintDatabase) {
        self.db = db
        self.beacons = db.beacons
    }

    func requestPermission() { ranger.requestPermission() }

    func start(uuidString: String, planID: String) {
        guard let db else {
            status = "No DB attached"
            return
        }

        rebuildTrainingCache(db: db, planID: planID)

        if trainX.isEmpty {
            status = "No training samples for \(planID)"
            xNorm = nil; yNorm = nil
            return
        }

        ranger.startRanging(uuidString: uuidString)
        status = "Ranging + regressing..."
        lastEMA = nil

        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 1.0 / max(updateHz, 0.2), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        ranger.stopRanging()
        timerCancellable?.cancel()
        timerCancellable = nil
        status = "Stopped"
        xNorm = nil; yNorm = nil
        confidence = 0.0
        lastEMA = nil
    }

    private func rebuildTrainingCache(db: FingerprintDatabase, planID: String) {
        let filtered = db.samples.filter { $0.planID == planID }
        self.beacons = db.beacons

        guard !filtered.isEmpty, !beacons.isEmpty else {
            trainX = []; trainXY = []; mean = []; std = []
            return
        }

        trainX = filtered.map { $0.vector }
        trainXY = filtered.map { (x: $0.xNorm, y: $0.yNorm) }

        let n = beacons.count
        mean = Array(repeating: 0.0, count: n)
        std = Array(repeating: 0.0, count: n)

        for j in 0..<n {
            var s = 0.0
            for i in 0..<trainX.count { s += trainX[i][j] }
            mean[j] = s / Double(trainX.count)
        }

        for j in 0..<n {
            var ss = 0.0
            for i in 0..<trainX.count {
                let d = trainX[i][j] - mean[j]
                ss += d * d
            }
            std[j] = sqrt(ss / Double(trainX.count)) + 1e-6
        }

        for i in 0..<trainX.count {
            for j in 0..<n {
                trainX[i][j] = (trainX[i][j] - mean[j]) / std[j]
            }
        }

        status = "Training ready (\(trainX.count) samples)"
    }

    private func tick() {
        guard !trainX.isEmpty, !beacons.isEmpty else { return }
        if ranger.live.isEmpty {
            xNorm = nil; yNorm = nil; confidence = 0.0
            return
        }

        var liveVec = Array(repeating: rssiFloor, count: beacons.count)

        for (id, rssi) in ranger.live {
            let key = "\(id.major)_\(id.minor)"
            if let idx = beacons.firstIndex(of: key) {
                liveVec[idx] = Double(rssi)
            }
        }

        for j in 0..<liveVec.count {
            liveVec[j] = (liveVec[j] - mean[j]) / std[j]
        }

        var dists: [(d: Double, i: Int)] = []
        dists.reserveCapacity(trainX.count)

        for i in 0..<trainX.count {
            dists.append((euclidean(trainX[i], liveVec), i))
        }
        dists.sort { $0.d < $1.d }

        let kEff = min(k, dists.count)
        let neighbors = Array(dists.prefix(kEff))

        let eps = 1e-3
        var wx = 0.0, wy = 0.0, wsum = 0.0
        for n in neighbors {
            let w = 1.0 / (n.d + eps)
            let t = trainXY[n.i]
            wx += w * t.x
            wy += w * t.y
            wsum += w
        }

        guard wsum > 0 else { return }

        var x = wx / wsum
        var y = wy / wsum

        let avgD = neighbors.map { $0.d }.reduce(0.0, +) / Double(kEff)
        confidence = 1.0 / (1.0 + avgD)

        x = min(max(x, 0.0), 1.0)
        y = min(max(y, 0.0), 1.0)

        if let prev = lastEMA {
            x = prev.x + emaAlpha * (x - prev.x)
            y = prev.y + emaAlpha * (y - prev.y)
        }
        lastEMA = (x, y)

        xNorm = x
        yNorm = y
    }

    private func euclidean(_ a: [Double], _ b: [Double]) -> Double {
        var s = 0.0
        for i in 0..<min(a.count, b.count) {
            let d = a[i] - b[i]
            s += d * d
        }
        return sqrt(s)
    }
}
