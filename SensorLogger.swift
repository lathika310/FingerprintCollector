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
            if let error {
                self.status = "Barometer error"
                print(error)
                return
            }
            if let data {
                // pressure reported in kPa
                self.pressureKPa = data.pressure.doubleValue
            }
        }
    }

    func stopBarometer() {
        altimeter.stopRelativeAltitudeUpdates()
        status = "Barometer: stopped"
    }
}

