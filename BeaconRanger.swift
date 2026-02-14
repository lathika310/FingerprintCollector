import Foundation
import CoreLocation

struct BeaconID: Hashable {
    let major: Int
    let minor: Int
}

final class BeaconRanger: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var uuid: UUID?

    private let offlineTimeout: TimeInterval = 3.0

    // LIVE RSSI
    @Published var live: [BeaconID: Int] = [:]
    @Published var status: String = "Idle"

    // Capture (window)
    @Published var isCapturing = false
    @Published var secondsLeft = 0
    @Published var windowMedians: [BeaconID: Int] = [:]

    @Published private(set) var captureSampleCounts: [BeaconID: Int] = [:]
    @Published private(set) var discarded: Set<BeaconID> = []

    private var lastSeen: [BeaconID: Date] = [:]
    private var cleanupTimer: Timer?

    private var captureTimer: Timer?
    private var windowSamples: [BeaconID: [Int]] = [:]

    override init() {
        super.init()
        manager.delegate = self

        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pruneOfflineBeacons()
        }
    }

    deinit {
        cleanupTimer?.invalidate()
        captureTimer?.invalidate()
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startRanging(uuidString: String) {
        guard let u = UUID(uuidString: uuidString) else {
            status = "Bad UUID"
            return
        }

        uuid = u
        status = "Ranging..."
        live = [:]
        lastSeen = [:]

        isCapturing = false
        secondsLeft = 0
        windowMedians = [:]
        windowSamples = [:]
        discarded = []
        captureSampleCounts = [:]

        manager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: u))
    }

    func stopRanging() {
        guard let u = uuid else { return }
        manager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: u))

        status = "Stopped"
        uuid = nil

        live = [:]
        lastSeen = [:]

        stopCaptureInternal(clearStatus: false)
        windowSamples = [:]
        windowMedians = [:]
        discarded = []
        captureSampleCounts = [:]
    }

    // MARK: - Capture

    func startCapture(windowSeconds: Int) {
        guard uuid != nil else { status = "Start ranging first"; return }

        isCapturing = true
        secondsLeft = windowSeconds
        windowSamples = [:]
        windowMedians = [:]
        discarded = []
        captureSampleCounts = [:]
        status = "Capturing..."

        captureTimer?.invalidate()
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { return }
            self.secondsLeft -= 1
            if self.secondsLeft <= 0 {
                t.invalidate()
                self.finishCapture()
            }
        }
    }

    func stopCapture() {
        stopCaptureInternal(clearStatus: true)
    }

    private func stopCaptureInternal(clearStatus: Bool) {
        captureTimer?.invalidate()
        captureTimer = nil
        if isCapturing, clearStatus { status = "Capture stopped" }
        isCapturing = false
        secondsLeft = 0
    }

    private func finishCapture() {
        isCapturing = false
        status = "Capture complete"

        var meds: [BeaconID: Int] = [:]
        for (id, vals) in windowSamples {
            guard !discarded.contains(id) else { continue }
            if let med = median(vals) { meds[id] = med }
        }
        windowMedians = meds
    }

    private func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        let m = s.count / 2
        if s.count % 2 == 0 { return Int(Double(s[m-1] + s[m]) / 2.0) }
        return s[m]
    }

    // MARK: - Offline handling

    private func pruneOfflineBeacons() {
        let now = Date()

        for (id, seenTime) in lastSeen {
            if now.timeIntervalSince(seenTime) > offlineTimeout {
                lastSeen.removeValue(forKey: id)
                live.removeValue(forKey: id)

                if isCapturing {
                    discarded.insert(id)
                    windowSamples.removeValue(forKey: id)
                    captureSampleCounts[id] = 0
                }
            }
        }

        if uuid != nil, live.isEmpty, status.hasPrefix("Ranging") {
            status = "Ranging... (no beacons)"
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager,
                         didRange beacons: [CLBeacon],
                         satisfying constraint: CLBeaconIdentityConstraint) {

        let now = Date()

        for b in beacons where b.rssi != 0 {
            let id = BeaconID(major: b.major.intValue, minor: b.minor.intValue)
            live[id] = b.rssi
            lastSeen[id] = now

            if isCapturing && !discarded.contains(id) {
                windowSamples[id, default: []].append(b.rssi)
                captureSampleCounts[id] = (windowSamples[id]?.count ?? 0)
            }
        }

        if uuid != nil && !beacons.isEmpty {
            status = "Ranging..."
        }
    }
}

