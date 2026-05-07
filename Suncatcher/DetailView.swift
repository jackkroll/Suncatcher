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
    @ObservedObject var viewmodel : CloudForecastViewModel
    @State var errorReload: Bool = false
    @State private var didLoadInitialForecast = false
    @State var modelSelection: CloudForecastModel = .nws
    @State var modelSelectionSheetIsPresented: Bool = false
    @AppStorage("preferredLocationModel") private var preferredLocationModel: CloudForecastModel = .hrdps
    @Namespace private var transition
    var locationManager: LocationManager?
    let isCurrentLocation: Bool

    init(
        viewmodel: CloudForecastViewModel,
        isCurrentLocation: Bool = false,
        locationManager: LocationManager? = nil
    ) {
        self.viewmodel = viewmodel
        self.isCurrentLocation = isCurrentLocation
        self.locationManager = locationManager
        _modelSelection = State(initialValue: viewmodel.selectedModel)
    }

    var body: some View {
        ZStack {
            CloudCoverMeshBackground(cloudCover: viewmodel.currentForecast?.cloudCoverFraction ?? 0.5)
                ScrollView {
                    VStack {
                        if isCurrentLocation {
                            HStack(spacing: 10) {
                                Image(systemName: "location.fill")
                                    .symbolRenderingMode(.hierarchical)

                                Text("Showing forecast for your current location")
                                    .font(.caption)
                                    .fontWeight(.medium)

                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .padding()
                            .glassEffect()
                        }

                        if let forecast: CloudForecast = viewmodel.currentForecast {
                            Text(forecast.summarize())
                                .font(.headline)
                            LazyVStack(pinnedViews: [.sectionHeaders]) {
                                ForEach(forecast.daySections) { section in
                                    Section {
                                        ForEach(section.hours) { hour in
                                            ForecastHourRow(hour: hour)
                                        }
                                    } header: {
                                        if !Calendar.current.isDateInToday(section.day) {
                                            ForecastDaySeparator(date: section.day)
                                        }
                                    }
                                }
                            }
                            .redacted(reason: viewmodel.isLoading ? .invalidated : [])
                        }
                        else if let errorMessage = viewmodel.errorMessage {
                            ContentUnavailableView("An error occured",systemImage: "exclamationmark.triangle.fill", description: Text(errorMessage))
                            Button {
                                Task {
                                    withAnimation {
                                        errorReload = true
                                    }
                                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                                    await refreshForecast(recalculateCurrentLocation: true, forceReload: true)
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
                        
                        if !isCurrentLocation {
                            Button(role: .destructive) {
                                deleteSavedLocation()
                            } label: {
                                Text("Remove from saved")
                            }
                            .buttonStyle(.bordered)
                            .buttonSizing(.flexible)
                        }
                        Spacer()
                        Text("\(CloudForecastModel.attributionFootnote)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .animation(.snappy(duration: 1), value: viewmodel.forecast != nil)
                    
        }
                .refreshable {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await refreshForecast(recalculateCurrentLocation: true, forceReload: true)
                }
        }
                
        .onAppear {
            guard !didLoadInitialForecast else { return }
            didLoadInitialForecast = true

            Task {
                await refreshForecast(recalculateCurrentLocation: false)
            }
        }
        .navigationTitle(viewmodel.locationName ?? (isCurrentLocation ? "Current Location" : "City Name"))
        .animation(.easeInOut, value: viewmodel.locationName)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $modelSelectionSheetIsPresented) {
            ModelSelectionView(modelSelection: $modelSelection)
                .presentationDetents([.fraction(3/4)])
                .navigationTransition(
                            .zoom(sourceID: "modelSelection", in: transition)
                        )
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    withAnimation {
                        modelSelectionSheetIsPresented.toggle()
                    }
                } label: {
                    Text(modelSelection.menuTitle)
                        .fixedSize()
                }
                .matchedTransitionSource(id: "modelSelection", in: transition)
            }
            
            ToolbarSpacer(.flexible, placement: .bottomBar)
            if isCurrentLocation {
                ToolbarItem(placement: .bottomBar) {
                    NavigationLink {
                        ListView(locationManager: LocationManager())
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
        }
        .onChange(of: modelSelection) { _, newValue in
            viewmodel.selectedModel = newValue

            Task(priority: .userInitiated) {
                await refreshForecast(recalculateCurrentLocation: false)
            }
            if isCurrentLocation {
                preferredLocationModel = newValue
            } else {
                try? modelContext.save()
            }
        }
    
    }

    private func refreshForecast(recalculateCurrentLocation: Bool, forceReload: Bool = false) async {
        if recalculateCurrentLocation, isCurrentLocation, let locationManager, let currentLocation = await locationManager.currentLocationRequest() {
            viewmodel.updateLocation(currentLocation)
        }
        await viewmodel.loadForecast(force: forceReload)
        await viewmodel.fetchLocationName()
    }

    private func deleteSavedLocation() {
        modelContext.delete(viewmodel.savedLocation)
        try? modelContext.save()
        dismiss()
    }

}

private struct ForecastDaySection: Identifiable {
    let day: Date
    var hours: [CloudForecastHour]

    var id: Date {
        day
    }
}

private struct ForecastDaySeparator: View {
    let date: Date

    private var title: String {
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(height: 1)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()

            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}

private struct ForecastHourRow: View {
    let hour: CloudForecastHour

    var body: some View {
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
        .background(Material.thinMaterial)
        .clipShape(Capsule())
    }
}

struct CurrentLocationForecastView: View {
    @ObservedObject var locationManager: LocationManager
    @StateObject private var viewmodel: CloudForecastViewModel
    let location: CLLocation

    init(location: CLLocation, locationManager: LocationManager, preferredLocationModel: CloudForecastModel) {
        self.location = location
        self.locationManager = locationManager
        _viewmodel = StateObject(
            wrappedValue: CloudForecastViewModel(
                savedLocation: SavedLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    cloudForecastModel: preferredLocationModel
                )
            )
        )
    }

    var body: some View {
        CurrentLocationDetailView(
            location: location,
            locationManager: locationManager,
            viewmodel: viewmodel
        )
    }
}

private struct CurrentLocationDetailView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var viewmodel: CloudForecastViewModel
    let location: CLLocation

    init(location: CLLocation, locationManager: LocationManager, viewmodel: CloudForecastViewModel) {
        self.location = location
        self.locationManager = locationManager
        self.viewmodel = viewmodel
    }

    var body: some View {
        DetailView(
            viewmodel: viewmodel,
            isCurrentLocation: true,
            locationManager: locationManager
        )
        .task(id: location.forecastIdentity) {
            viewmodel.updateLocation(location)
        }
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

    var daySections: [ForecastDaySection] {
        let calendar = Calendar.current
        var sections: [ForecastDaySection] = []

        for hour in hours {
            let day = calendar.startOfDay(for: hour.time)

            if sections.last?.day == day {
                sections[sections.count - 1].hours.append(hour)
            } else {
                sections.append(ForecastDaySection(day: day, hours: [hour]))
            }
        }

        return sections
    }
}

struct ShortDetailView : View {
    @ObservedObject var viewmodel : CloudForecastViewModel
    @State var cloudCover: Double? = nil
    let isCurrentLocation: Bool

    init(viewmodel: CloudForecastViewModel, isCurrentLocation: Bool = false) {
        self.viewmodel = viewmodel
        self.isCurrentLocation = isCurrentLocation
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading){
                HStack {
                    if isCurrentLocation {
                        Image(systemName: "location.fill")
                    }
                    Text(viewmodel.locationName ?? "City Name")
                        .redacted(reason: viewmodel.locationName != nil ? [] : [.placeholder])
                }
                if !isCurrentLocation {
                    Text("\(viewmodel.location.latitude.formatted(.number.precision(.fractionLength(3))))°, \(viewmodel.location.longitude.formatted(.number.precision(.fractionLength(3))))°")
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.secondary)
                }
                
            }
            Spacer()
            if let cloudCover = cloudCover {
                HStack {
                    ViewThatFits {
                        HStack {
                            Text("\(Int((1 - cloudCover) * 100))% Sunny")
                                .fontDesign(.rounded)
                                .fontWeight(.semibold)
                                .allowsTightening(true)
                                .lineLimit(1)
                            Image(systemName: "sun.max.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
                        HStack {
                            Text("\(Int((1 - cloudCover) * 100))% Sunny")
                                .fontDesign(.rounded)
                                .fontWeight(.semibold)
                                .allowsTightening(true)
                                .lineLimit(1)
                        }
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                        }
                    }
                    
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
                await loadPreviewForecast()
            }

        }
        .onChange(of: viewmodel.selectedModel) { _, _ in
            Task {
                await loadPreviewForecast()
            }
        }
        .padding()
        .frame(maxWidth: 500)
        .glassEffect(.regular.tint(.blue.mix(with: .gray, by: cloudCover ?? 0).opacity(0.5)))
    }

    private func loadPreviewForecast() async {
        if !viewmodel.hasForecastForCurrentLocationAndModel {
            cloudCover = nil
        }

        await viewmodel.loadForecast()
        await viewmodel.fetchLocationName()
        if let coverage = viewmodel.forecast?.hours.first?.coverage {
            cloudCover = coverage / 100
        }
    }
}

private extension CLLocation {
    var forecastIdentity: String {
        let latitude = (coordinate.latitude * 10_000).rounded() / 10_000
        let longitude = (coordinate.longitude * 10_000).rounded() / 10_000
        return "\(latitude),\(longitude)"
    }
}

#Preview {
    NavigationStack {
        DetailView(
            viewmodel: CloudForecastViewModel(
                savedLocation: SavedLocation(latitude: 42.3297, longitude: -83.0425),
               
            ),  isCurrentLocation: true
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
