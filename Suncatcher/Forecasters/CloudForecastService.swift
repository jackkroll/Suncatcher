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
    let model: CloudForecastModel
    let modelName: String
    let hours: [CloudForecastHour]
    
    func summarize(firstN: Int = 12) -> String {
        let hours: [CloudForecastHour] = Array(hours.prefix(firstN))
        guard let first = hours.first, let last = hours.last else {
            return "No forecast hours available."
        }

        let average = hours.map(\.coverage).reduce(0, +) / Double(hours.count)
        let minimum = hours.map(\.coverage).min() ?? average
        let maximum = hours.map(\.coverage).max() ?? average
        let trend = last.coverage - first.coverage

        let forecastWindow = forecastWindowDescription(for: hours)
        let opening: String
        switch average {
        case ..<15:
            opening = "Mostly clear through the next \(forecastWindow)"
        case ..<35:
            opening = "Mostly clear to partly cloudy through the next \(forecastWindow)"
        case ..<60:
            opening = "A mixed sky is likely through the next \(forecastWindow)"
        case ..<80:
            opening = "Mostly cloudy conditions look likely through the next \(forecastWindow)"
        default:
            opening = "Cloud cover stays heavy through the next \(forecastWindow)"
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

    private func forecastWindowDescription(for hours: [CloudForecastHour]) -> String {
        guard let first = hours.first, let last = hours.last else {
            return "forecast period"
        }

        let elapsed = Calendar(identifier: .gregorian).dateComponents([.hour], from: first.time, to: last.time).hour ?? 0
        let inclusiveHours = max(elapsed + 1, hours.count)
        return "\(inclusiveHours) hours"
    }
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

enum CloudForecastModel: String, CaseIterable, Identifiable, Sendable {
    case nws
    case hrdps
    case rdps
    case gdps
    case gepsMedian

    var id: String { rawValue }

    static let defaultModel: CloudForecastModel = .hrdps

    static func model(for id: String?) -> CloudForecastModel {
        guard let id, let model = CloudForecastModel(rawValue: id) else {
            return defaultModel
        }

        return model
    }

    var name: String {
        switch self {
        case .nws:
            return "NWS"
        case .hrdps:
            return "ECCC HRDPS 2.5 km"
        case .rdps:
            return "ECCC RDPS 10 km"
        case .gdps:
            return "ECCC GDPS 15 km"
        case .gepsMedian:
            return "ECCC GEPS median 39 km"
        }
    }

    var menuTitle: String {
        switch self {
        case .nws:
            return "NWS"
        case .hrdps:
            return "HRDPS 2.5 km"
        case .rdps:
            return "RDPS 10 km"
        case .gdps:
            return "GDPS 15 km"
        case .gepsMedian:
            return "GEPS median 39 km"
        }
    }

    var layerName: String {
        switch self {
        case .nws:
            return ""
        case .hrdps:
            return "HRDPS.CONTINENTAL_NT"
        case .rdps:
            return "RDPS.ETA_NT"
        case .gdps:
            return "GDPS_15km_TotalCloudCover"
        case .gepsMedian:
            return "GEPS.DIAG.3_NT.ERC50"
        }
    }

    var sampleStepHours: Int {
        switch self {
        case .gepsMedian:
            return 3
        default:
            return 1
        }
    }

    static let attributionFootnote = "Forecast model data: Government of Canada, Environment and Climate Change Canada, Meteorological Service of Canada."
}

struct CloudForecastService {
    private let session: URLSession
    private let baseURL = URL(string: "https://geo.weather.gc.ca/geomet")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchForecast(
        latitude: Double,
        longitude: Double,
        model: CloudForecastModel,
        samples: Int = 12
    ) async throws -> CloudForecast {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw CloudForecastError.invalidLocation
        }
        
        if model == .nws {
            return try await NWSForecastService(session: session).fetchForecast(latitude: latitude, longitude: longitude, hours: samples)
        }
        else {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
            let startTime = nextForecastTime(after: Date(), stepHours: model.sampleStepHours, calendar: calendar)
            
            let hourlyValues = try await withThrowingTaskGroup(of: CloudForecastHour.self) { group in
                for offset in 0..<samples {
                    let forecastTime = calendar.date(
                        byAdding: .hour,
                        value: offset * model.sampleStepHours,
                        to: startTime
                    ) ?? startTime
                    group.addTask {
                        let coverage = try await fetchCloudCover(
                            latitude: latitude,
                            longitude: longitude,
                            model: model,
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
                model: model,
                modelName: model.name,
                hours: hourlyValues
            )
        }
    }

    private func fetchCloudCover(
        latitude: Double,
        longitude: Double,
        model: CloudForecastModel,
        forecastTime: Date
    ) async throws -> Double {
        let requestURL = try makeFeatureInfoURL(
            latitude: latitude,
            longitude: longitude,
            model: model,
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

    private func nextForecastTime(after date: Date, stepHours: Int, calendar: Calendar) -> Date {
        let stepHours = max(stepHours, 1)
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)

        if (components.minute ?? 0) > 0 || (components.second ?? 0) > 0 || (components.nanosecond ?? 0) > 0 {
            components.hour = (components.hour ?? 0) + 1
        }

        components.minute = 0
        components.second = 0
        components.nanosecond = 0

        var forecastTime = calendar.date(from: components) ?? date
        while calendar.component(.hour, from: forecastTime) % stepHours != 0 {
            forecastTime = calendar.date(byAdding: .hour, value: 1, to: forecastTime) ?? forecastTime
        }

        return forecastTime
    }

    private func makeFeatureInfoURL(
        latitude: Double,
        longitude: Double,
        model: CloudForecastModel,
        time: Date?
    ) throws -> URL {
        let boxHalfWidth = 0.01
        let minLatitude = latitude - boxHalfWidth
        let maxLatitude = latitude + boxHalfWidth
        let minLongitude = longitude - boxHalfWidth
        let maxLongitude = longitude + boxHalfWidth
        let layerName = model.layerName

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

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

}


extension Error {
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
