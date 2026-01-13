import Foundation
import CoreLocation

struct BeaconID: Hashable {
    let major: Int
    let minor: Int
}

final class BeaconRanger: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var uuid: UUID?

    // LIVE RSSI + last seen time
    @Published var live: [BeaconID: Int] = [:]
    @Published var status: String = "Idle"

    private var lastSeen: [BeaconID: Date] = [:]
    private var cleanupTimer: Timer?

    override init() {
        super.init()
        manager.delegate = self

        // Every 1s, remove beacons not seen in the last 3s
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pruneOfflineBeacons(timeoutSeconds: 3.0)
        }
    }

    deinit {
        cleanupTimer?.invalidate()
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

        manager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: u))
    }

    func stopRanging() {
        guard let u = uuid else { return }
        manager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: u))
        status = "Stopped"
        live = [:]
        lastSeen = [:]
    }

    private func pruneOfflineBeacons(timeoutSeconds: TimeInterval) {
        let now = Date()
        var changed = false

        for (id, seenTime) in lastSeen {
            if now.timeIntervalSince(seenTime) > timeoutSeconds {
                lastSeen.removeValue(forKey: id)
                live.removeValue(forKey: id)
                changed = true
            }
        }

        // Optional: reflect if nothing is currently being seen
        if changed, uuid != nil, live.isEmpty, status == "Ranging..." {
            status = "Ranging... (no beacons)"
        }
    }

    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying constraint: CLBeaconIdentityConstraint) {
        let now = Date()

        // Update live beacons
        for b in beacons where b.rssi != 0 {
            let id = BeaconID(major: b.major.intValue, minor: b.minor.intValue)
            live[id] = b.rssi
            lastSeen[id] = now
        }

        if uuid != nil && !beacons.isEmpty && status.hasPrefix("Ranging") {
            status = "Ranging..."
        }
    }
}

