import SwiftUI

struct FingerprintRecord: Identifiable {
    let id = UUID()
    let timestamp: Date

    let planID: String
    let pointID: String
    let pointName: String
    let xNorm: Double
    let yNorm: Double

    let uuid: String
    let major: Int
    let minor: Int
    let rssi: Int

    let mode: String
}

struct FingerprintSample: Codable {
    let planID: String
    let xNorm: Double
    let yNorm: Double
    let vector: [Double]
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

