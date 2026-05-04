//
//  LocationManager.swift
//  Suncatcher
//
//  Created by Jack Kroll on 5/3/26.
//

import Combine
import CoreLocation
import Foundation

final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isUpdatingLocation = false
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager

    var coordinate: CLLocationCoordinate2D? {
        currentLocation?.coordinate
    }

    var canUseLocation: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            true
        default:
            false
        }
    }

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus

        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestAuthorization() {
        errorMessage = nil

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access is disabled. Enable it in Settings to use your current location."
        @unknown default:
            errorMessage = "Location authorization is in an unknown state."
        }
    }

    func requestLocation() {
        errorMessage = nil

        guard canUseLocation else {
            requestAuthorization()
            return
        }

        isUpdatingLocation = true
        manager.requestLocation()
    }

    func currentLocationRequest() async -> CLLocation? {
        errorMessage = nil

        guard canUseLocation else {
            requestAuthorization()
            return currentLocation
        }

        let previousLocation = currentLocation
        isUpdatingLocation = true
        manager.requestLocation()

        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(250))

            if let currentLocation, currentLocation != previousLocation {
                return currentLocation
            }

            if !isUpdatingLocation {
                return currentLocation
            }
        }

        isUpdatingLocation = false
        return currentLocation
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        isUpdatingLocation = false
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if canUseLocation {
            requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        isUpdatingLocation = false
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isUpdatingLocation = false
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
