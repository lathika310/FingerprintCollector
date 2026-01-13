//
//  ContentView.swift
//  FingerprintCollector
//
//  Created by Lathika on 2026-01-12.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var ranger = BeaconRanger()
    @State private var uuidString = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

    var body: some View {
        VStack(spacing: 12) {
            Text("iBeacon Ranging Test").font(.headline)

            TextField("Beacon UUID", text: $uuidString)
                .textInputAutocapitalization(.characters)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Request Permission") { ranger.requestPermission() }
                Button("Start") { ranger.startRanging(uuidString: uuidString) }
                Button("Stop") { ranger.stopRanging() }
            }

            Text(ranger.status).foregroundStyle(.secondary)

            List {
                ForEach(ranger.ranged.keys.sorted(by: { ($0.major, $0.minor) < ($1.major, $1.minor) }), id: \.self) { k in
                    HStack {
                        Text("Major \(k.major)  Minor \(k.minor)")
                        Spacer()
                        Text("\(ranger.ranged[k] ?? 0) dBm")
                    }
                }
            }
        }
        .padding()
    }
}

