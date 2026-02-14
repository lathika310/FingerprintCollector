//
//  FloorPlanEditorView.swift
//  FingerprintCollector
//
//  Created by Lathika on 2026-02-13.
//


import SwiftUI

struct FloorPlanEditorView: View {
    @EnvironmentObject private var store: FloorPlanStore

    @State private var plan: FloorPlanID = .eng4North
    @State private var selectedPointID: UUID? = nil

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var renameText: String = ""

    var body: some View {
        VStack(spacing: 10) {
            Text("Regression Point Editor").font(.headline)

            Picker("Plan", selection: $plan) {
                ForEach(FloorPlanID.allCases) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Reset View") {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }

                Button("Clear Points") {
                    store.clear(plan: plan)
                    selectedPointID = nil
                    renameText = ""
                }

                Spacer()

                Text("Points: \(store.points(for: plan).count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.03)

                    ZStack {
                        Image(plan.assetName)
                            .resizable()
                            .scaledToFit()

                        pointsLayer(in: geo.size)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .scaleEffect(scale)
                    .offset(offset)
                    .simultaneousGesture(panGesture())
                    .simultaneousGesture(zoomGesture())
                    .simultaneousGesture(tapToAddGesture(in: geo.size))
                }
                .clipShape(Rectangle())
            }
            .padding(.horizontal)

            Divider()

            if let pid = selectedPointID,
               let p = store.points(for: plan).first(where: { $0.id == pid }) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected: \(p.name)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(format: "x=%.4f  y=%.4f (normalized)", p.xNorm, p.yNorm))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        TextField("Rename", text: $renameText)
                            .textFieldStyle(.roundedBorder)

                        Button("Save Name") {
                            store.renamePoint(
                                plan: plan,
                                pointID: pid,
                                newName: renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                    }

                    Button(role: .destructive) {
                        store.deletePoint(plan: plan, pointID: pid)
                        selectedPointID = nil
                        renameText = ""
                    } label: {
                        Text("Delete Selected Point")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

            } else {
                Text("Tip: pinch to zoom, drag to pan, tap to add a point, drag a point to move it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: plan) { _, _ in
            selectedPointID = nil
            renameText = ""
        }
    }

    private func pointsLayer(in container: CGSize) -> some View {
        let pts = store.points(for: plan)

        return ZStack {
            ForEach(pts) { p in
                let screen = normToScreen(p, in: container)
                let inv = 1.0 / max(scale, 1e-6)

                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .overlay(
                            Circle().stroke(Color.black.opacity(0.7),
                                            lineWidth: selectedPointID == p.id ? 2 : 1)
                        )
                        .contentShape(Rectangle().inset(by: -10))

                    Text(p.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .offset(y: -18)
                }
                .scaleEffect(inv)
                .position(screen)
                .onTapGesture {
                    selectedPointID = p.id
                    renameText = p.name
                }
                .highPriorityGesture(pointDragGesture(point: p, container: container))
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

    private func tapToAddGesture(in container: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let basePoint = undoTransform(value.location, in: container)
                let norm = screenToNorm(basePoint, in: container)
                store.addPoint(plan: plan, xNorm: norm.x, yNorm: norm.y)
            }
    }

    private func pointDragGesture(point: AnchorPoint, container: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let basePoint = undoTransform(v.location, in: container)
                let norm = screenToNorm(basePoint, in: container)
                store.updatePoint(plan: plan, pointID: point.id, xNorm: norm.x, yNorm: norm.y)
            }
    }

    private func normToScreen(_ p: AnchorPoint, in container: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(p.xNorm) * container.width,
                y: CGFloat(p.yNorm) * container.height)
    }

    private func screenToNorm(_ pt: CGPoint, in container: CGSize) -> (x: Double, y: Double) {
        let x = Double(pt.x / max(container.width, 1))
        let y = Double(pt.y / max(container.height, 1))
        return (x: min(max(x, 0.0), 1.0), y: min(max(y, 0.0), 1.0))
    }

    private func undoTransform(_ pt: CGPoint, in container: CGSize) -> CGPoint {
        let unpanned = CGPoint(x: pt.x - offset.width, y: pt.y - offset.height)
        let center = CGPoint(x: container.width / 2, y: container.height / 2)
        return CGPoint(
            x: center.x + (unpanned.x - center.x) / max(scale, 1e-6),
            y: center.y + (unpanned.y - center.y) / max(scale, 1e-6)
        )
    }
}
