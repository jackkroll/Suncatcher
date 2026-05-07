//
//  ContentView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 5/3/26.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @AppStorage("preferredLocationModel") private var preferredLocationModel: CloudForecastModel = .hrdps
    var body: some View {
        NavigationStack {
            VStack {
                if let userLocation = locationManager.currentLocation {
                    CurrentLocationForecastView(
                        location: userLocation,
                        locationManager: locationManager,
                        preferredLocationModel: preferredLocationModel
                    )
                }
                else {
                    ListView(locationManager: locationManager)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
