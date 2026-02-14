//
//  FingerprintDatabase.swift
//  FingerprintCollector
//
//  Created by Lathika on 2026-02-13.
//


import Foundation

final class FingerprintDatabase: ObservableObject {
    @Published var beacons: [String] = []
    @Published var samples: [FingerprintSample] = []
    @Published var status: String = "No dataset loaded"

    private let storageKey = "fingerprint_db_v2_regression"

    init() { load() }

    func clear() {
        beacons = []
        samples = []
        status = "Cleared"
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func save() {
        do {
            let payload = Payload(beacons: beacons, samples: samples, status: status)
            let data = try JSONEncoder().encode(payload)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("DB save failed:", error)
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            beacons = payload.beacons
            samples = payload.samples
            status = payload.status
        } catch {
            print("DB load failed:", error)
        }
    }

    private struct Payload: Codable {
        let beacons: [String]
        let samples: [FingerprintSample]
        let status: String
    }
}
