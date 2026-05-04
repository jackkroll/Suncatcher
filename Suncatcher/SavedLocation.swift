//
//  SavedLocation.swift
//  Suncatcher
//
//  Created by Jack Kroll on 5/1/26.
//

import CoreLocation
import Foundation
import SwiftData

@Model
final class SavedLocation {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    var cloudForecastModelID: String = CloudForecastModel.defaultModel.id

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        createdAt: Date = .now,
        cloudForecastModel: CloudForecastModel = .defaultModel
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.cloudForecastModelID = cloudForecastModel.id
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var cloudForecastModel: CloudForecastModel {
        get {
            CloudForecastModel.model(for: cloudForecastModelID)
        }
        set {
            cloudForecastModelID = newValue.id
        }
    }
}
