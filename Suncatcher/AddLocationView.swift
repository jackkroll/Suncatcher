//
//  AddLocationView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/30/26.
//

import SwiftUI
import MapKit
import SwiftData

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var position: MapCameraPosition = .camera(Self.globeCamera)
    @State private var cameraUpdateTask: Task<Void, Never>?
    @State var searchText: String = ""
    @State var searchResults : [MKMapItem] = []
    var body: some View {
        NavigationStack {
            VStack {
                Map(position: $position){
                    ForEach(searchResults, id: \.identifier) { result in
                        Marker(item: result)
                    }
                    UserAnnotation()
                }
                .searchable(text: $searchText)
                .onChange(of: searchText) { _, newValue in
                    search(for: newValue)
                }
                .onChange(of: searchResults.first?.cameraKey) { _, _ in
                    guard let firstResult = searchResults.first else {
                        cameraUpdateTask?.cancel()
                        return
                    }

                    updateCamera(for: firstResult)
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControlVisibility(.visible)

            }
            .safeAreaInset(edge: .bottom) {
                    HStack {
                        if let possibleLocation = searchResults.first {
                            VStack {
                                Text(possibleLocation.address?.fullAddress ?? "Address")
                                    .font(.title3)
                                Text(possibleLocation.location.coordinate.latitude.description + ", " + possibleLocation.location.coordinate.longitude.description)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fontDesign(.monospaced)
                            }
                            Spacer()
                            Button(role: .confirm) {
                                add(possibleLocation)
                            } label: {
                                Image(systemName: "plus")
                                    .bold()
                            }
                            .padding()
                            .buttonBorderShape(.circle)

                            .buttonStyle(.glassProminent)
                        }
                        if searchResults.isEmpty {
                            if searchText.isEmpty {
                                ContentUnavailableView("Search to add a location", systemImage: "magnifyingglass")
                            }
                            else {
                                ContentUnavailableView("No Results Found", systemImage: "exclamationmark.magnifyingglass")
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: 100)
                    .glassEffect(in: ConcentricRectangle(corners: .concentric(minimum: 30), isUniform: true))
                    .animation(.easeInOut, value: searchText)
                    .padding(.horizontal)
                    .padding(.bottom)
                }


        }
    }

    private func add(_ mapItem: MKMapItem) {
        let coordinate = mapItem.location.coordinate
        let location = SavedLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        modelContext.insert(location)
        try? modelContext.save()
        dismiss()
    }

    private static let globeCamera = MapCamera(
        centerCoordinate: .init(latitude: 20, longitude: -80),
        distance: 100_000_000
    )

    private static func overviewCamera(for coordinate: CLLocationCoordinate2D) -> MapCamera {
        MapCamera(centerCoordinate: coordinate, distance: 100_000_000)
    }

    private static func locationCamera(for coordinate: CLLocationCoordinate2D) -> MapCamera {
        MapCamera(centerCoordinate: coordinate, distance: 15_000, heading: 0, pitch: 45)
    }

    private func updateCamera(for mapItem: MKMapItem) {
        cameraUpdateTask?.cancel()

        let locationKey = mapItem.cameraKey
        let coordinate = mapItem.location.coordinate

        withAnimation(.easeInOut(duration: 1)) {
            position = .camera(Self.overviewCamera(for: coordinate))
        }

        cameraUpdateTask = Task {
            try? await Task.sleep(for: .seconds(2))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard searchResults.first?.cameraKey == locationKey else { return }

                withAnimation(.easeInOut(duration: 1)) {
                    position = .camera(Self.locationCamera(for: coordinate))
                }
            }
        }
    }

    private func search(for query: String) {
        guard !query.isEmpty else {
            cameraUpdateTask?.cancel()
            cameraUpdateTask = nil
            searchResults = []

            withAnimation(.easeInOut(duration: 1)) {
                position = .camera(Self.globeCamera)
            }

            return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        Task {
            let search = MKLocalSearch(request: request)
            let response = try? await search.start()

            await MainActor.run {
                guard query == searchText else { return }
                searchResults = response?.mapItems ?? []
            }
        }
    }
}

private extension MKMapItem {
    var cameraKey: String {
        let coordinate = location.coordinate
        return "\(coordinate.latitude),\(coordinate.longitude),\(name ?? "")"
    }
}

#Preview {
    AddLocationView()
        .modelContainer(for: SavedLocation.self, inMemory: true)
}
