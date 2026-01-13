import Foundation
import CoreLocation

struct BeaconID: Hashable {
    let major: Int
    let minor: Int
}

func median(_ values: [Int]) -> Int? {
    guard !values.isEmpty else { return nil }
    let s = values.sorted()
    let m = s.count / 2
    if s.count % 2 == 0 { return Int(Double(s[m-1] + s[m]) / 2.0) }
    return s[m]
}

final class BeaconRanger: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var uuid: UUID?

    // Settings
    private let offlineTimeout: TimeInterval = 3.0

    // LIVE RSSI
    @Published var live: [BeaconID: Int] = [:]
    @Published var status: String = "Idle"

    // Capture (window)
    @Published var isCapturing = false
    @Published var secondsLeft = 0
    @Published var windowMedians: [BeaconID: Int] = [:]

    private var lastSeen: [BeaconID: Date] = [:]
    private var cleanupTimer: Timer?

    private var captureTimer: Timer?
    private var windowSamples: [BeaconID: [Int]] = [:]
    private var discardedInWindow: Set<BeaconID> = []

    override init() {
        super.init()
        manager.delegate = self

        // Prune offline beacons once per second
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

        // Clear previous capture results
        isCapturing = false
        secondsLeft = 0
        windowMedians = [:]
        windowSamples = [:]
        discardedInWindow = []

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
    }

    // MARK: - Capture

    func startCapture(windowSeconds: Int) {
        guard uuid != nil else { status = "Start ranging first"; return }

        // Reset capture state
        isCapturing = true
        secondsLeft = windowSeconds
        windowSamples = [:]
        windowMedians = [:]
        discardedInWindow = []
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
        if isCapturing, clearStatus {
            status = "Capture stopped"
        }
        isCapturing = false
        secondsLeft = 0
    }

    private func finishCapture() {
        isCapturing = false
        status = "Capture complete"

        // Compute medians for beacons that were NOT discarded
        var meds: [BeaconID: Int] = [:]
        for (id, vals) in windowSamples {
            guard !discardedInWindow.contains(id) else { continue }
            if let med = median(vals) {
                meds[id] = med
            }
        }
        windowMedians = meds
    }

    // MARK: - Offline handling

    private func pruneOfflineBeacons() {
        let now = Date()
        var removedAny = false

        for (id, seenTime) in lastSeen {
            if now.timeIntervalSince(seenTime) > offlineTimeout {
                // Remove from live view
                lastSeen.removeValue(forKey: id)
                live.removeValue(forKey: id)
                removedAny = true

                // If capturing, DISCARD this beacon entirely for this window (your choice 2=B)
                if isCapturing {
                    discardedInWindow.insert(id)
                    windowSamples.removeValue(forKey: id) // drop all samples too
                }
            }
        }

        if removedAny, uuid != nil, live.isEmpty, status.hasPrefix("Ranging") {
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

            // Update live
            live[id] = b.rssi
            lastSeen[id] = now

            // During capture, only collect if NOT discarded
            if isCapturing && !discardedInWindow.contains(id) {
                windowSamples[id, default: []].append(b.rssi)
            }
        }

        if uuid != nil && status.hasPrefix("Ranging") && !beacons.isEmpty {
            status = "Ranging..."
        }
    }
}

