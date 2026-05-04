//
//  AddLocationView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/30/26.
//

import SwiftUI
import MapKit
import SwiftData
import Combine

struct AddLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager: LocationManager
    @FocusState var searchIsFocused: Bool
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State var searchText: String = ""
    @State private var resolvingCompletionKey: String?
    @State private var errorMessage: String?
    @State private var selectedModel = CloudForecastModel.defaultModel

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView("Search for a location", systemImage: "magnifyingglass")

                        if let currentLocation = locationManager.currentLocation {
                            Button {
                                add(currentLocation)
                            } label: {
                                Label("Use Current Location", systemImage: "location.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            LocationServicesSuggestionView(
                                locationManager: locationManager,
                                message: "You can also enable location services to always view the conditions for your current location."
                            )
                        }
                    }
                }
                else if searchCompleter.isSearching {
                    ProgressView()
                }
                else if let errorMessage = errorMessage ?? searchCompleter.errorMessage {
                    ContentUnavailableView("Search failed", systemImage: "exclamationmark.magnifyingglass", description: Text(errorMessage))
                }
                else if searchCompleter.completions.isEmpty {
                    ContentUnavailableView("No results available for \"\(searchText)\"", systemImage: "magnifyingglass")
                }
                else {
                    List {
                        ForEach(searchCompleter.completions, id: \.self) { completion in
                            Button {
                                Task {
                                    await add(completion)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(completion.title)
                                            .foregroundStyle(.primary)

                                        if !completion.subtitle.isEmpty {
                                            Text(completion.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if resolvingCompletionKey == key(for: completion) {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(resolvingCompletionKey != nil)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
            .onAppear {
                searchIsFocused = true
            }
            .searchable(text: $searchText)
            .searchFocused($searchIsFocused)
            .onChange(of: searchText) { _, newValue in
                errorMessage = nil
                searchCompleter.queryFragment = newValue
            }
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
    }

    private func add(_ completion: MKLocalSearchCompletion) async {
        resolvingCompletionKey = key(for: completion)
        defer {
            resolvingCompletionKey = nil
        }

        do {
            let request = MKLocalSearch.Request(completion: completion)
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            if let mapItem = response.mapItems.first {
                add(mapItem)
            } else {
                errorMessage = "No matching location could be resolved."
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func add(_ mapItem: MKMapItem) {
        let coordinate = mapItem.location.coordinate
        add(coordinate)
    }

    private func add(_ location: CLLocation) {
        add(location.coordinate)
    }

    private func add(_ coordinate: CLLocationCoordinate2D) {
        let location = SavedLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            cloudForecastModel: selectedModel
        )

        modelContext.insert(location)
        try? modelContext.save()
        dismiss()
    }

    private func key(for completion: MKLocalSearchCompletion) -> String {
        "\(completion.title)|\(completion.subtitle)"
    }
}

private final class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var completions: [MKLocalSearchCompletion] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    var queryFragment: String = "" {
        didSet {
            let trimmedQuery = queryFragment.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedQuery.isEmpty else {
                completer.queryFragment = ""
                completions = []
                isSearching = false
                errorMessage = nil
                return
            }

            isSearching = true
            errorMessage = nil
            completer.queryFragment = trimmedQuery
        }
    }

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = .address
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
        isSearching = false
        errorMessage = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        completions = []
        isSearching = false
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

#Preview {
    
    AddLocationView(locationManager: LocationManager())
        .modelContainer(for: SavedLocation.self, inMemory: true)
}
