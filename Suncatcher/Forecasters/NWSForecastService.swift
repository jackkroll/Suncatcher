//
//  NWSForecastService.swift
//  Suncatcher
//
//  Created by Jack Kroll on 5/5/26.
//

import Foundation


struct NWSForecastService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchForecast(latitude: Double, longitude: Double, hours: Int = 12) async throws -> CloudForecast {
        let point = try await fetchPoint(lat: latitude, lon: longitude)
        let grid = try await fetchGridData(from: point.forecastGridDataURL)

        let mapped: [CloudForecastHour] = grid.properties.skyCover.values
            .compactMap { entry in
                guard let value = entry.value,
                      let date = parseValidTime(entry.validTime, invalidIfBefore: .now.addingTimeInterval(60 * 60 * -1)) else {
                    return nil
                }
                return CloudForecastHour(time: date, coverage: value)
            }

        guard !mapped.isEmpty else {
            throw CloudForecastError.missingCloudValue
        }

        return CloudForecast(
            model: .nws,
            modelName: "NWS Hourly Forecast",
            hours: mapped,
        )
    }
    
    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw CloudForecastError.invalidResponse
        }
    }
    
    private func fetchPoint(lat: Double, lon: Double) async throws -> NWSPointResponse {
        let url = URL(string: "https://api.weather.gov/points/\(lat),\(lon)")!

        var request = URLRequest(url: url)
        request.setValue("SuncatcherAppUser/1.0 (dev:me@jackk.dev)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
            
        return try JSONDecoder().decode(NWSPointResponse.self, from: data)
    }
    
    private func fetchGridData(from url: URL) async throws -> NWSGridResponse {
        var request = URLRequest(url: url)
        request.setValue("SuncatcherApp/1.0 (dev:me@jackk.dev)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        return try JSONDecoder().decode(NWSGridResponse.self, from: data)
    }
    
    private func parseValidTime(_ string: String, invalidIfBefore invalidDate: Date? = nil) -> Date? {
        let start = string.split(separator: "/").first ?? ""
        let parsedDate : Date? = ISO8601DateFormatter().date(from: String(start))
        if let invalidDate = invalidDate {
            if let parsedDate = parsedDate{
                if parsedDate < invalidDate {
                    return nil
                }
                else {
                    return parsedDate
                }
            } else {
                return nil
            }
        } else {
            return parsedDate
        }
    }
    
    
    struct NWSPointResponse: Decodable {
        let properties: Properties

        struct Properties: Decodable {
            let forecastGridData: URL
        }

        var forecastGridDataURL: URL { properties.forecastGridData }
    }
    
    struct NWSGridResponse: Decodable {
        let properties: Properties

        struct Properties: Decodable {
            let skyCover: SkyCover
        }

        struct SkyCover: Decodable {
            let values: [Value]
        }

        struct Value: Decodable {
            let validTime: String
            let value: Double?
        }
    }
}
