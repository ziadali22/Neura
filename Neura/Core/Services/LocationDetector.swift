import CoreLocation
import Foundation
import Combine

@MainActor
final class LocationDetector: NSObject, ObservableObject {
    @Published var isDetecting = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private var onResult: ((String, String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func detect(onResult: @escaping (String, String) -> Void) {
        self.onResult = onResult
        isDetecting = true
        errorMessage = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            isDetecting = false
            errorMessage = "Location access denied. Enable it in Settings."
        }
    }
}

extension LocationDetector: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if isDetecting { manager.requestLocation() }
            case .denied, .restricted:
                isDetecting = false
                errorMessage = "Location access denied. Enable it in Settings."
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                isDetecting = false
                if let place = placemarks?.first {
                    let city = place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? ""
                    let country = place.country ?? ""
                    onResult?(city, country)
                } else {
                    errorMessage = "Could not determine location."
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            isDetecting = false
            errorMessage = "Could not detect location."
        }
    }
}
