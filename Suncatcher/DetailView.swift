//
//  DetailView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 4/28/26.
//

import SwiftUI
import CoreLocation
import MapKit
import SwiftData

struct DetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @StateObject var viewmodel : CloudForecastViewModel
    @State var errorReload: Bool = false
    var body: some View {
        ZStack {
            CloudCoverMeshBackground(cloudCover: viewmodel.forecast?.cloudCoverFraction ?? 0.5)
                ScrollView {
                    VStack {
                        if let forecast: CloudForecast = viewmodel.forecast {
                            Text(forecast.summary)
                                .font(.headline)
                            HStack {
                                Form {
                                    Text(forecast.modelName)
                                        .padding()
                                        .bold()
                                        .glassEffect()
                                }
                            }
                            VStack {
                                ForEach(forecast.hours) { hour in
                                    HStack {
                                        Text(hour.time, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                                            .frame(width: 64, alignment: .leading)
                                        Text(hour.label)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: hour.imageName)
                                            .bold()
                                        Text("\(Int(hour.coverage.rounded()))%")
                                            .monospacedDigit()
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                    .padding()
                                    .glassEffect()
                                }
                            }
                        }
                        else if let errorMessage = viewmodel.errorMessage {
                            ContentUnavailableView("An error occured",systemImage: "exclamationmark.triangle.fill", description: Text(errorMessage))
                            Button {
                                Task {
                                    withAnimation {
                                        errorReload = true
                                    }
                                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                                    await viewmodel.loadForecast()
                                    withAnimation {
                                        errorReload = false
                                    }
                                }
                            } label: {
                                if !errorReload {
                                    Text("Reload forecast")
                                } else {
                                    ProgressView()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(errorReload)
                        }
                        else {
                                VStack {
                                    if let errorMessage = viewmodel.errorMessage {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 30, height: 30)
                                                .symbolRenderingMode(.hierarchical)
                                            VStack(alignment: .leading) {
                                                Text("An error occured")
                                                    .font(.callout)
                                                    .bold()
                                                    
                                                Text(errorMessage)
                                                    .font(.caption2)
                                            }
                                            .frame(maxWidth: .infinity)
                                            
                                        }
                                        .padding()
                                        .frame(maxWidth: 500)
                                        .glassEffect()
                                        
                                        
                                            
                                    }
                                    ForEach(0..<12) { _ in
                                        HStack {
                                            Text("XXX")
                                                .frame(width: 64, alignment: .leading)
                                            Text("XXXXXXX")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Image(systemName: "cloud.fill")
                                                .bold()
                                            Text("XX%")
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                        }
                                        .font(.subheadline)
                                        .padding()
                                        .glassEffect()
                                        .redacted(reason: .placeholder)
                                    }
                                }
                            }
                        Button(role: .destructive) {
                            deleteSavedLocation()
                        } label: {
                            Text("Remove from saved")
                        }
                        .buttonStyle(.bordered)
                        .buttonSizing(.flexible)
                    }
                    .padding()
                    .animation(.snappy(duration: 1), value: viewmodel.forecast != nil)
                    
        }
                .refreshable {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await viewmodel.loadForecast()
                }
        }
                
        .onAppear {
            Task {
                await viewmodel.fetchLocationName()
                await viewmodel.loadForecast()
            }
        }
        .navigationTitle(viewmodel.locationName ?? "City Name")
        .animation(.easeInOut, value: viewmodel.locationName)
        .navigationBarTitleDisplayMode(.large)
    
    }

    private func deleteSavedLocation() {
        modelContext.delete(viewmodel.savedLocation)
        try? modelContext.save()
        dismiss()
    }
}

private struct CloudCoverMeshBackground: View {
    let cloudCover: Double

    private var baseColor: Color {
        .blue.mix(with: .gray, by: cloudCover)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let drift = sin(timeline.date.timeIntervalSinceReferenceDate / 9) * 0.035

            ZStack {
                baseColor
                    .opacity(0.18)

                MeshGradient(
                    width: 3,
                    height: 3,
                    points: points,
                    colors: colors(drift: drift)
                )
                .opacity(0.42)

                LinearGradient(
                    colors: [
                        .white.opacity(0.16),
                        .clear,
                        .black.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var points: [SIMD2<Float>] {
        [
            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
            [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
        ]
    }

    private func colors(drift: Double) -> [Color] {
        let cloudCover = clamped(self.cloudCover + drift)
        let clearer = clamped(cloudCover - 0.08)
        let cloudier = clamped(cloudCover + 0.08)

        return [
            .blue.mix(with: .gray, by: clearer),
            .blue.mix(with: .gray, by: cloudCover),
            .blue.mix(with: .gray, by: cloudier),
            .blue.mix(with: .gray, by: clearer).opacity(0.82),
            .blue.mix(with: .gray, by: cloudCover).opacity(0.92),
            .blue.mix(with: .gray, by: cloudier).opacity(0.84),
            .blue.mix(with: .gray, by: cloudCover),
            .blue.mix(with: .gray, by: cloudier),
            .blue.mix(with: .gray, by: clearer)
        ]
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private extension CloudForecast {
    var cloudCoverFraction: Double {
        guard !hours.isEmpty else {
            return 0.5
        }

        let averageCoverage = hours.map(\.coverage).reduce(0, +) / Double(hours.count)
        return min(max(averageCoverage / 100, 0), 1)
    }
}

struct ShortDetailView : View {
    @StateObject var viewmodel : CloudForecastViewModel
    @State var cloudCover: Double? = nil
    var body: some View {
        HStack {
            VStack(alignment: .leading){
                Text(viewmodel.locationName ?? "City Name")
                    .redacted(reason: viewmodel.locationName != nil ? [] : [.placeholder])
                Text("\(viewmodel.location.latitude.formatted(.number.precision(.fractionLength(3))))°, \(viewmodel.location.longitude.formatted(.number.precision(.fractionLength(3))))°")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let cloudCover = cloudCover {
                HStack {
                    
                    Text("\(Int((1-(cloudCover)) * 100))% Sunny")
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
            }
            
            Image(systemName: "arrow.right.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 35, height: 35)
            
        }
        .onAppear {
            Task {
                await viewmodel.loadForecast()
                await viewmodel.fetchLocationName()
                if let coverage = viewmodel.forecast?.hours.first?.coverage {
                    cloudCover = coverage / 100
                }
            }

        }
        .padding()
        .frame(maxWidth: 500)
        .glassEffect(.regular.tint(.blue.mix(with: .gray, by: cloudCover ?? 0).opacity(0.5)))
    }
}

#Preview {
    NavigationStack {
        DetailView(
            viewmodel: CloudForecastViewModel(
                savedLocation: SavedLocation(latitude: 42.3297, longitude: -83.0425)
            )
        )
    }
    .modelContainer(for: SavedLocation.self, inMemory: true)
}

#Preview {
    VStack {
        ShortDetailView(
            viewmodel: CloudForecastViewModel(
                savedLocation: SavedLocation(latitude: 42.3297, longitude: -83.0425)
            )
        )
        .padding()
    }
}
