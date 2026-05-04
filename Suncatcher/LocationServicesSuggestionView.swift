//
//  LocationServicesSuggestionView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 5/3/26.
//

import CoreLocation
import SwiftUI

struct LocationServicesSuggestionView: View {
    @ObservedObject var locationManager: LocationManager
    var message = "To quickly view conditions around you, enable location services."

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title2)

            Text(message)
                .font(.callout)

            if locationManager.isUpdatingLocation {
                ProgressView()
            } else {
                Button(actionTitle) {
                    handleAction()
                }
                .buttonStyle(.bordered)
            }
        }
        .foregroundStyle(.secondary)
        .padding()
        .glassEffect(in: RoundedRectangle(cornerRadius: 15))
    }

    private var actionTitle: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            "Settings"
        default:
            "Enable"
        }
    }

    private func handleAction() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                openURL(settingsURL)
            }
        default:
            locationManager.requestLocation()
        }
    }
}
#Preview {
    LocationServicesSuggestionView(locationManager: LocationManager())
}
