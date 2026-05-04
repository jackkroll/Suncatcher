//
//  ContentView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 5/3/26.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @StateObject var locationManager = LocationManager()
    var body: some View {
        NavigationStack {
            VStack {
                if let userLocation = locationManager.currentLocation {
                    CurrentLocationDetailView(
                        location: userLocation,
                        locationManager: locationManager
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
