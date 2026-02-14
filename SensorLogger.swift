import Foundation
import CoreMotion

final class SensorLogger: ObservableObject {
    private let altimeter = CMAltimeter()

    @Published var pressureKPa: Double?
    @Published var status: String = "Barometer: idle"

    func startBarometer() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            status = "Barometer: not available"
            return
        }

        status = "Barometer: running"
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }
            if error != nil {
                self.status = "Barometer error"
                return
            }
            if let data {
                self.pressureKPa = data.pressure.doubleValue
            }
        }
    }

    func stopBarometer() {
        altimeter.stopRelativeAltitudeUpdates()
        status = "Barometer: stopped"
    }
}

