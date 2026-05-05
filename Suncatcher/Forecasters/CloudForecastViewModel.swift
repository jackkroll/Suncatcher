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
    
    var location: CLLocationCoordinate2D {
        savedLocation.coordinate
    }
    
    var selectedModel: CloudForecastModel {
        get {
            savedLocation.cloudForecastModel
        }
        set {
            savedLocation.cloudForecastModel = newValue
        }
    }
    
    init(savedLocation: SavedLocation) {
        self.savedLocation = savedLocation
    }
    
    func updateLocation(_ location: CLLocation) {
        savedLocation.latitude = location.coordinate.latitude
        savedLocation.longitude = location.coordinate.longitude
    }
    
    func loadForecast() async {
        let previousErrorMessage = errorMessage
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }
        
        do {
                forecast = try await service.fetchForecast(
                    latitude: location.latitude,
                    longitude: location.longitude,
                    model: selectedModel
                )
        } catch where error.isCancellation {
            errorMessage = previousErrorMessage
            return
        } catch {
            forecast = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    
    func fetchLocationName() async {
        if let request = MKReverseGeocodingRequest(location:
                                                    CLLocation(latitude: self.location.latitude,
                                                               longitude: self.location.longitude)) {
            if let mapItems = try? await request.mapItems {
                locationName = mapItems.first?.addressRepresentations?.cityWithContext(.short)
            }
        }
    }
}
