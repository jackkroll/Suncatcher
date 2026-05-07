//
//  CloudForecastViewModel.swift
//  Suncatcher
//
//  Created by Jack Kroll on 5/5/26.
//

import Foundation
import MapKit
import Combine

@MainActor
final class CloudForecastViewModel: ObservableObject {
    @Published var savedLocation: SavedLocation
    @Published var locationName: String?
    @Published var forecast: CloudForecast?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service = CloudForecastService()
    private var loadedForecastRequest: ForecastRequest?
    private var loadingForecastRequest: ForecastRequest?
    private var loadedLocationNameRequest: LocationRequest?
    private var loadingLocationNameRequest: LocationRequest?

    var hasForecastForCurrentLocationAndModel: Bool {
        forecast != nil && loadedForecastRequest == ForecastRequest(location: location, model: selectedModel)
    }

    var currentForecast: CloudForecast? {
        hasForecastForCurrentLocationAndModel ? forecast : nil
    }
    
    var location: CLLocationCoordinate2D {
        savedLocation.coordinate
    }
    
    var selectedModel: CloudForecastModel {
        get {
            savedLocation.cloudForecastModel
        }
        set {
            guard savedLocation.cloudForecastModel != newValue else {
                return
            }

            savedLocation.cloudForecastModel = newValue
            invalidateForecast()
        }
    }
    
    init(savedLocation: SavedLocation) {
        self.savedLocation = savedLocation
    }
    
    func updateLocation(_ location: CLLocation) {
        let oldLocationRequest = LocationRequest(location: self.location)
        savedLocation.latitude = location.coordinate.latitude
        savedLocation.longitude = location.coordinate.longitude

        guard oldLocationRequest != LocationRequest(location: self.location) else {
            return
        }

        forecast = nil
        locationName = nil
        errorMessage = nil
        invalidateForecast()
        loadedLocationNameRequest = nil
    }

    private func invalidateForecast() {
        forecast = nil
        errorMessage = nil
        loadedForecastRequest = nil
    }
    
    func loadForecast(force: Bool = false) async {
        let request = ForecastRequest(location: location, model: selectedModel)

        if !force, hasForecastForCurrentLocationAndModel {
            return
        }

        if loadingForecastRequest == request {
            return
        }

        let previousErrorMessage = errorMessage
        loadingForecastRequest = request
        isLoading = true
        errorMessage = nil

        defer {
            if loadingForecastRequest == request {
                loadingForecastRequest = nil
                isLoading = false
            }
        }
        
        do {
            let forecast = try await service.fetchForecast(
                latitude: request.latitude,
                longitude: request.longitude,
                model: request.model
            )
            guard loadingForecastRequest == request else {
                return
            }

            self.forecast = forecast
            loadedForecastRequest = request
        } catch where error.isCancellation {
            if loadingForecastRequest == request {
                errorMessage = previousErrorMessage
            }
            return
        } catch {
            guard loadingForecastRequest == request else {
                return
            }

            forecast = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    func fetchLocationName() async {
        let locationRequest = LocationRequest(location: location)

        if locationName != nil, loadedLocationNameRequest == locationRequest {
            return
        }

        if loadingLocationNameRequest == locationRequest {
            return
        }

        loadingLocationNameRequest = locationRequest
        defer {
            if loadingLocationNameRequest == locationRequest {
                loadingLocationNameRequest = nil
            }
        }

        let location = CLLocation(latitude: locationRequest.latitude, longitude: locationRequest.longitude)
        if let request = MKReverseGeocodingRequest(location: location) {
            if let mapItems = try? await request.mapItems {
                guard loadingLocationNameRequest == locationRequest else {
                    return
                }

                locationName = mapItems.first?.addressRepresentations?.cityWithContext(.short)
                loadedLocationNameRequest = locationRequest
            }
        }
    }
}

private struct ForecastRequest: Equatable {
    let latitude: Double
    let longitude: Double
    let model: CloudForecastModel

    init(location: CLLocationCoordinate2D, model: CloudForecastModel) {
        self.latitude = Self.normalized(location.latitude)
        self.longitude = Self.normalized(location.longitude)
        self.model = model
    }

    private static func normalized(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }
}

private struct LocationRequest: Equatable {
    let latitude: Double
    let longitude: Double

    init(location: CLLocationCoordinate2D) {
        self.latitude = Self.normalized(location.latitude)
        self.longitude = Self.normalized(location.longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = Self.normalized(latitude)
        self.longitude = Self.normalized(longitude)
    }

    private static func normalized(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }
}
