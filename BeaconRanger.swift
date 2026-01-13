//
//  BeaconRanger.swift
//  FingerprintCollector
//
//  Created by Lathika on 2026-01-12.
//

import Foundation
import CoreLocation

struct BeaconID: Hashable {
    let major: Int
    let minor: Int
}

final class BeaconRanger: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var ranged: [BeaconID: Int] = [:]   // last RSSI per beacon
    @Published var status: String = "Idle"

    private var uuid: UUID?

    override init() {
        super.init()
        manager.delegate = self
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
        ranged = [:]
        manager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: u))
    }

    func stopRanging() {
        guard let u = uuid else { return }
        manager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: u))
        status = "Stopped"
    }

    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying constraint: CLBeaconIdentityConstraint) {
        for b in beacons where b.rssi != 0 {
            let id = BeaconID(major: b.major.intValue, minor: b.minor.intValue)
            ranged[id] = b.rssi
        }
    }
}
