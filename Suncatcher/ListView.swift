//
//  List View.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/28/26.
//

import SwiftUI
import MapKit
import SwiftData
import Combine

struct ListView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var locationManager: LocationManager
    @Query(sort: \SavedLocation.createdAt, order: .reverse) private var locations: [SavedLocation]
    @State private var addLocationIsPresented: Bool = false

    var body: some View {
            ScrollView {
                if locations.isEmpty {
                    ContentUnavailableView("No Locations Added", systemImage: "mappin.and.ellipse", description: Text("Add a location to see its cloud cover forecast"))
                }
                
                LazyVStack {
                    if !locations.isEmpty && !locationManager.canUseLocation {
                        LocationServicesSuggestionView(locationManager: locationManager)
                        .padding(.bottom)
                        
                    }
                    ForEach(locations) { location in
                        let viewmodel = CloudForecastViewModel(savedLocation: location)
                        VStack(spacing: 8) {
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
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                delete(location)
                            } label: {
                                Label("Delete Location", systemImage: "trash")
                            }
                        }
                    }

                    if !locations.isEmpty {
                        Text("\(CloudForecastModel.attributionFootnote)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Saved Locations")
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        addLocationIsPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $addLocationIsPresented) {
                AddLocationView(locationManager: locationManager)
            }
    }

    private func delete(_ location: SavedLocation) {
        modelContext.delete(location)
        try? modelContext.save()
    }

    private func modelBinding(for viewmodel: CloudForecastViewModel) -> Binding<CloudForecastModel> {
        Binding {
            viewmodel.selectedModel
        } set: { newModel in
            viewmodel.selectedModel = newModel
            try? modelContext.save()
        }
    }
}

#Preview("No Locations") {
    ListView(locationManager: LocationManager())
        .modelContainer(ContentViewPreviewData.container())
}

#Preview("One Location") {
    ListView(locationManager: LocationManager())
        .modelContainer(ContentViewPreviewData.container(with: [
            SavedLocation(
                latitude: 42.3314,
                longitude: -83.0458
            )
        ]))
}

#Preview("Saved Locations") {
    ListView(locationManager: LocationManager())
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
