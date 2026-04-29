//
//  ContentView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/28/26.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State var searchText: String = ""
    @State var cloudCover: CGFloat = 0
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    VStack(alignment: .leading){
                        Text("Location Name")
                        Text("42.3297°N, 83.0425°W")
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack {
                        Text("\(Int((1-cloudCover) * 100))% Sunny")
                            .fontDesign(.rounded)
                            .fontWeight(.semibold)
                        Image(systemName: "sun.max.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                    }
                    .padding(7)
                    .background(Material.thin)
                    .clipShape(Capsule())
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35, height: 35)
                    
                }
                .padding()
                .frame(maxWidth: 500)
                .glassEffect(.regular.tint(.blue.mix(with: .gray, by: cloudCover).opacity(0.5)))
                Slider(value: $cloudCover, in: 0...1)
            }
        }
    }
}

#Preview {
    ContentView()
}
