//
//  FloorPlanStore.swift
//  FingerprintCollector
//
//  Created by Lathika on 2026-02-13.
//


import Foundation

final class FloorPlanStore: ObservableObject {
    @Published private(set) var pointsByPlan: [FloorPlanID: [AnchorPoint]] = [:]
    private let storageKey = "floorplan_anchor_points_v1"

    init() { load() }

    func points(for plan: FloorPlanID) -> [AnchorPoint] {
        pointsByPlan[plan] ?? []
    }

    func addPoint(plan: FloorPlanID, xNorm: Double, yNorm: Double) {
        let nextIndex = (pointsByPlan[plan]?.count ?? 0) + 1
        let p = AnchorPoint(name: "A\(nextIndex)", xNorm: clamp01(xNorm), yNorm: clamp01(yNorm))
        pointsByPlan[plan, default: []].append(p)
        save()
    }

    func updatePoint(plan: FloorPlanID, pointID: UUID, xNorm: Double, yNorm: Double) {
        guard var arr = pointsByPlan[plan],
              let idx = arr.firstIndex(where: { $0.id == pointID }) else { return }
        arr[idx].xNorm = clamp01(xNorm)
        arr[idx].yNorm = clamp01(yNorm)
        pointsByPlan[plan] = arr
        save()
    }

    func renamePoint(plan: FloorPlanID, pointID: UUID, newName: String) {
        guard var arr = pointsByPlan[plan],
              let idx = arr.firstIndex(where: { $0.id == pointID }) else { return }
        arr[idx].name = newName.isEmpty ? arr[idx].name : newName
        pointsByPlan[plan] = arr
        save()
    }

    func deletePoint(plan: FloorPlanID, pointID: UUID) {
        guard var arr = pointsByPlan[plan] else { return }
        arr.removeAll { $0.id == pointID }
        pointsByPlan[plan] = arr
        save()
    }

    func clear(plan: FloorPlanID) {
        pointsByPlan[plan] = []
        save()
    }

    private struct Payload: Codable {
        let points: [String: [AnchorPoint]]
    }

    private func save() {
        do {
            var dict: [String: [AnchorPoint]] = [:]
            for (k, v) in pointsByPlan { dict[k.rawValue] = v }
            let data = try JSONEncoder().encode(Payload(points: dict))
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("FloorPlanStore save failed:", error)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            var out: [FloorPlanID: [AnchorPoint]] = [:]
            for (k, v) in payload.points {
                if let id = FloorPlanID(rawValue: k) { out[id] = v }
            }
            pointsByPlan = out
        } catch {
            print("FloorPlanStore load failed:", error)
        }
    }

    private func clamp01(_ v: Double) -> Double {
        min(max(v, 0.0), 1.0)
    }
}
