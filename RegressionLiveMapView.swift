//
//  RegressionLiveMapView.swift
//  FingerprintCollector
//
//  Created by Lathika on 2026-02-13.
//


import SwiftUI

struct RegressionLiveMapView: View {
    @EnvironmentObject private var db: FingerprintDatabase
    @StateObject private var locator = LiveKNNRegressor()

    @State private var plan: FloorPlanID = .eng4North
    @State private var uuidString: String = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 10) {
            Text("Live Location (Regression)").font(.headline)

            Text(db.status).font(.caption).foregroundStyle(.secondary)
            Text(locator.status).font(.caption).foregroundStyle(.secondary)

            Picker("Plan", selection: $plan) {
                ForEach(FloorPlanID.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack(spacing: 10) {
                TextField("Beacon UUID", text: $uuidString)
                    .textInputAutocapitalization(.characters)
                    .textFieldStyle(.roundedBorder)

                Button("Perm") { locator.requestPermission() }
                Button("Start") { locator.start(uuidString: uuidString, planID: plan.rawValue) }
                Button("Stop") { locator.stop() }
            }
            .padding(.horizontal)

            HStack {
                if let x = locator.xNorm, let y = locator.yNorm {
                    Text(String(format: "x=%.3f y=%.3f", x, y))
                } else {
                    Text("x=— y=—")
                }

                Spacer()

                Text(String(format: "conf: %.0f%%", locator.confidence * 100))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.03)

                    ZStack {
                        Image(plan.assetName)
                            .resizable()
                            .scaledToFit()

                        if let x = locator.xNorm, let y = locator.yNorm {
                            let pt = CGPoint(x: CGFloat(x) * geo.size.width,
                                             y: CGFloat(y) * geo.size.height)
                            let inv = 1.0 / max(scale, 1e-6)

                            Circle()
                                .fill(Color.blue)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .scaleEffect(inv)
                                .position(pt)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .scaleEffect(scale)
                    .offset(offset)
                    .simultaneousGesture(panGesture())
                    .simultaneousGesture(zoomGesture())
                }
                .clipShape(Rectangle())
            }
            .padding(.horizontal)
        }
        .onAppear { locator.attachDatabase(db) }
        .onDisappear { locator.stop() }
        .onChange(of: plan) { _, _ in
            if locator.status.contains("Ranging") {
                locator.start(uuidString: uuidString, planID: plan.rawValue)
            }
        }
    }

    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 1.0), 8.0)
            }
            .onEnded { _ in lastScale = scale }
    }

    private func panGesture() -> some Gesture {
        DragGesture()
            .onChanged { v in
                offset = CGSize(width: lastOffset.width + v.translation.width,
                                height: lastOffset.height + v.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }
}
