//
//  ContentView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/28/26.
//

import SwiftUI
import MapKit
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedLocation.createdAt, order: .reverse) private var locations: [SavedLocation]
    var body: some View {
        NavigationStack {
            ScrollView {
                if locations.isEmpty {
                    ContentUnavailableView("No Locations Added", systemImage: "mappin.and.ellipse", description: Text("Add a location to see its cloud cover forecast"))
                }

                LazyVStack {
                    ForEach(locations) { location in
                        let viewmodel = CloudForecastViewModel(savedLocation: location)
                        NavigationLink {
                            DetailView(
                                viewmodel: viewmodel
                            )
                        } label: {
                            ShortDetailView(
                                viewmodel: viewmodel
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(location)
                            } label: {
                                Label("Delete Location", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Suncatcher")
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    NavigationLink {
                        AddLocationView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func delete(_ location: SavedLocation) {
        modelContext.delete(location)
        try? modelContext.save()
    }
}

#Preview("No Locations") {
    ContentView()
        .modelContainer(ContentViewPreviewData.container())
}

#Preview("One Location") {
    ContentView()
        .modelContainer(ContentViewPreviewData.container(with: [
            SavedLocation(
                latitude: 42.3314,
                longitude: -83.0458
            )
        ]))
}

#Preview("Saved Locations") {
    ContentView()
        .modelContainer(ContentViewPreviewData.container(with: [
            SavedLocation(
                latitude: 42.3314,
                longitude: -83.0458,
                createdAt: .now
            ),
            SavedLocation(
                latitude: 41.8781,
                longitude: -87.6298,
                createdAt: .now.addingTimeInterval(-60)
            ),
            SavedLocation(
                latitude: 43.6532,
                longitude: -79.3832,
                createdAt: .now.addingTimeInterval(-120)
            )
        ]))
}

@MainActor
private enum ContentViewPreviewData {
    static func container(with locations: [SavedLocation] = []) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: SavedLocation.self, configurations: configuration)

        for location in locations {
            container.mainContext.insert(location)
        }

        return container
    }
}
