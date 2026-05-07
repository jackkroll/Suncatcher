//
//  ModelSelectionView.swift
//  Suncatcher
//
//  Created by Jack Kroll on 5/7/26.
//

import SwiftUI

struct ModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var modelSelection: CloudForecastModel
    var body: some View {
        NavigationStack {
            ScrollView {
                SingleSection(title: "National Weather Service", description: "Model provided by the United Stated NWS, good for most US users") {
                    SingleModel(modelSelection: $modelSelection, modelCode: .nws, modelName: "NWS", modelDescription: "High resulution model with up to 7 days forecast")
                }
                SingleSection(title: "ECCC", description: "Models provided by the Canadian Meteorological Centre, good for Canadian and North American users") {
                    SingleModel(modelSelection: $modelSelection, modelCode: .hrdps, modelName: "HRDPS 2.5 km", modelDescription: "High-resolution model with ~48 hours prediction")
                    SingleModel(modelSelection: $modelSelection, modelCode: .rdps, modelName: "RDPS 10 km", modelDescription: "Regional model at 10 km resolution")
                    SingleModel(modelSelection: $modelSelection, modelCode: .gdps, modelName: "GDPS 15 km", modelDescription: "Global model at 15 km resolution")
                    SingleModel(modelSelection: $modelSelection, modelCode: .gepsMedian, modelName: "GEPS median 39 km", modelDescription: "Ensemble median at 39 km, 3‑hour steps")
                }
            }
            .onChange(of: modelSelection) {
                dismiss()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
            .navigationTitle("Select a model")
            .navigationBarTitleDisplayMode(.inline)
        }
        
    }
}
struct SingleSection<Content: View>: View {
    let title: String
    let description: String
    let content: Content
    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading){
            Text(title)
                .font(.title2)
                .bold()
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
            VStack {
                content
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SingleModel: View {
    @Binding var modelSelection: CloudForecastModel
    let modelCode: CloudForecastModel
    let modelName: String
    let modelDescription: String
    var body: some View {
        Button {
            withAnimation {
                modelSelection = modelCode
            }
        } label: {
            VStack(alignment: .leading){
                HStack {
                    Text(modelName)
                        .font(.headline)
                    if modelCode == modelSelection {
                        Text("(Selected)")
                            .fontDesign(.rounded)
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                }
                Text(modelDescription)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(5)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(.foreground)
        .disabled(modelCode == modelSelection)
        
    }
}

#Preview {
    @Previewable @State var modelSelection: CloudForecastModel = .nws
    ModelSelectionView(modelSelection: $modelSelection)
}
