//
//  CloudForecastService.swift
//  Suncatcher
//
//  Created by Codex on 4/28/26.
//

import Combine
import Foundation
import SwiftUI
import CoreLocation
import MapKit

struct CloudForecast: Sendable {
    let modelName: String
    let hours: [CloudForecastHour]
    let summary: String
}

struct CloudForecastHour: Identifiable, Sendable {
    let time: Date
    let coverage: Double

    var id: Date { time }
    var imageName: String {
        switch coverage {
        case ..<15:
            return "sun.max"
        case ..<35:
            return "sun.min"
        case ..<60:
            return "cloud.sun"
        case ..<80:
            return "cloud"
        default:
            return "cloud.fill"
        }
    }
    var label: String {
        switch coverage {
        case ..<15:
            return "Clear"
        case ..<35:
            return "Mostly clear"
        case ..<60:
            return "Partly cloudy"
        case ..<80:
            return "Mostly cloudy"
        default:
            return "Overcast"
        }
    }
}

enum CloudForecastError: LocalizedError {
    case invalidLocation
    case invalidResponse
    case missingCloudValue

    var errorDescription: String? {
        switch self {
        case .invalidLocation:
            return "Enter a valid latitude and longitude."
        case .invalidResponse:
            return "The ECCC response could not be parsed."
        case .missingCloudValue:
            return "No cloud-cover values came back from ECCC for this location."
        }
    }
}

struct CloudForecastService {
    private let session: URLSession
    private let baseURL = URL(string: "https://geo.weather.gc.ca/geomet")!
    private let layerName = "HRDPS.CONTINENTAL_NT"
    private let modelName = "ECCC HRDPS 2.5 km"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchForecast(latitude: Double, longitude: Double, hours: Int = 12) async throws -> CloudForecast {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw CloudForecastError.invalidLocation
        }

        let calendar = Calendar(identifier: .gregorian)
        let startTime = calendar.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Date()

        let hourlyValues = try await withThrowingTaskGroup(of: CloudForecastHour.self) { group in
            for offset in 0..<hours {
                let forecastTime = calendar.date(byAdding: .hour, value: offset, to: startTime) ?? startTime
                group.addTask {
                    let coverage = try await fetchCloudCover(
                        latitude: latitude,
                        longitude: longitude,
                        forecastTime: forecastTime
                    )
                    return CloudForecastHour(time: forecastTime, coverage: coverage)
                }
            }

            var results: [CloudForecastHour] = []
            for try await hour in group {
                results.append(hour)
            }
            return results.sorted { $0.time < $1.time }
        }

        return CloudForecast(
            modelName: modelName,
            hours: hourlyValues,
            summary: summarize(hours: hourlyValues)
        )
    }

    private func fetchCloudCover(latitude: Double, longitude: Double, forecastTime: Date) async throws -> Double {
        let requestURL = try makeFeatureInfoURL(
            latitude: latitude,
            longitude: longitude,
            time: forecastTime
        )

        let (data, response) = try await session.data(from: requestURL)
        try validate(response: response)

        guard let value = parseValue(named: "value_0", from: data) ?? parseValue(named: "value_list", from: data),
              let coverage = Double(value) else {
            throw CloudForecastError.missingCloudValue
        }

        return coverage
    }

    private func makeFeatureInfoURL(latitude: Double, longitude: Double, time: Date?) throws -> URL {
        let boxHalfWidth = 0.01
        let minLatitude = latitude - boxHalfWidth
        let maxLatitude = latitude + boxHalfWidth
        let minLongitude = longitude - boxHalfWidth
        let maxLongitude = longitude + boxHalfWidth

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "SERVICE", value: "WMS"),
            URLQueryItem(name: "VERSION", value: "1.3.0"),
            URLQueryItem(name: "REQUEST", value: "GetFeatureInfo"),
            URLQueryItem(name: "LAYERS", value: layerName),
            URLQueryItem(name: "QUERY_LAYERS", value: layerName),
            URLQueryItem(name: "CRS", value: "EPSG:4326"),
            URLQueryItem(name: "BBOX", value: "\(minLatitude),\(minLongitude),\(maxLatitude),\(maxLongitude)"),
            URLQueryItem(name: "WIDTH", value: "101"),
            URLQueryItem(name: "HEIGHT", value: "101"),
            URLQueryItem(name: "I", value: "50"),
            URLQueryItem(name: "J", value: "50"),
            URLQueryItem(name: "INFO_FORMAT", value: "text/plain")
        ]

        if let time {
            queryItems.append(URLQueryItem(name: "TIME", value: Self.iso8601Formatter.string(from: time)))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw CloudForecastError.invalidResponse
        }

        return url
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw CloudForecastError.invalidResponse
        }
    }

    private func parseValue(named field: String, from data: Data) -> String? {
        guard let body = String(data: data, encoding: .utf8) else {
            return nil
        }

        let prefix = "\(field) = '"
        guard let line = body.split(separator: "\n").first(where: { $0.contains(prefix) }),
              let range = line.range(of: prefix) else {
            return nil
        }

        let valueStart = line[range.upperBound...]
        guard let closingQuote = valueStart.firstIndex(of: "'") else {
            return nil
        }

        return String(valueStart[..<closingQuote])
    }

    private func summarize(hours: [CloudForecastHour]) -> String {
        guard let first = hours.first, let last = hours.last else {
            return "No forecast hours available."
        }

        let average = hours.map(\.coverage).reduce(0, +) / Double(hours.count)
        let minimum = hours.map(\.coverage).min() ?? average
        let maximum = hours.map(\.coverage).max() ?? average
        let trend = last.coverage - first.coverage

        let opening: String
        switch average {
        case ..<15:
            opening = "Mostly clear through the next \(hours.count) hours"
        case ..<35:
            opening = "Mostly clear to partly cloudy through the next \(hours.count) hours"
        case ..<60:
            opening = "A mixed sky is likely through the next \(hours.count) hours"
        case ..<80:
            opening = "Mostly cloudy conditions look likely through the next \(hours.count) hours"
        default:
            opening = "Cloud cover stays heavy through the next \(hours.count) hours"
        }

        let trendText: String
        switch trend {
        case let delta where delta <= -20:
            trendText = "Clouds ease later in the window."
        case let delta where delta >= 20:
            trendText = "Clouds build as the period goes on."
        default:
            trendText = "Coverage stays fairly steady."
        }

        return "\(opening), ranging from \(Int(minimum.rounded()))% to \(Int(maximum.rounded()))% coverage. \(trendText)"
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

}

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

    init(savedLocation: SavedLocation) {
        self.savedLocation = savedLocation
    }

    func loadForecast() async {
        let previousErrorMessage = errorMessage
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }

        do {
            forecast = try await service.fetchForecast(latitude: location.latitude, longitude: location.longitude)
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

private extension Error {
    var isCancellation: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError, urlError.code == .cancelled {
            return true
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
