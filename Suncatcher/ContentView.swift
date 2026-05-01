//
//  ContentView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/28/26.
//

import SwiftUI
import MapKit

struct ContentView: View {
    let locations: [CLLocationCoordinate2D] = []
    @State var searchText: String = ""
    @State var cloudCover: CGFloat = 0
    @State var addSheetIsPresented: Bool = false
    var body: some View {
        NavigationView {
            VStack {
                if locations.isEmpty {
                    ContentUnavailableView("No Locations Added", systemImage: "mappin.and.ellipse", description: Text("Add a location to see its cloud cover forecast"))
                }
                ForEach(locations, id: \.latitude) { location in
                    ShortDetailView(viewmodel: CloudForecastViewModel(location: location))
                }
            }
            .sheet(isPresented: $addSheetIsPresented) {
                AddLocationView()
            }
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        addSheetIsPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
