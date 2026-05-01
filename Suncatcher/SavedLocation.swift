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

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        createdAt: Date = .now
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
