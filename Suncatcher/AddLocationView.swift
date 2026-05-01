//
//  AddLocationView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/30/26.
//

import SwiftUI
import MapKit

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .camera(.init(centerCoordinate: .init(latitude: 20, longitude: -80), distance: pow(10,8)))
    @State var searchText: String = ""
    @State var searchResults : [MKMapItem] = []
    var body: some View {
        NavigationStack {
            VStack {
                Map(initialPosition: position){
                    ForEach(searchResults, id: \.identifier) { result in
                        Marker(item: result)
                    }
                    UserAnnotation()
                }
                .searchable(text: $searchText)
                .onChange(of: searchText) { _, newValue in
                    search(for: newValue)
                }
                .mapStyle(.hybrid(elevation: .realistic))
                .mapControlVisibility(.visible)
                
            }.toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
    }
    
    private func search(for query: String) {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
        request.resultTypes = .address
            Task {
                let search = MKLocalSearch(request: request)
                let response = try? await search.start()
                searchResults = response?.mapItems ?? []
            }
        }
}

#Preview {
    AddLocationView()
}
