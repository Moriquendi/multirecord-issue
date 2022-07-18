//
//  ContentView.swift
//  MultiRecorder
//
//  Created by Michał Śmiałko on 18/07/2022.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var recorder = Recorder()

    var body: some View {
        VStack {
            DevicesPicker(selection: $recorder.selectedDevices)

            Divider()

            Text("Recorded time: \(recorder.recordedTime)")

            Button(action: recorder.toggle) {
                Text("\(recorder.isRecording ? "Stop" : "Start")")
            }

            if let error = recorder.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
            }
        }
        .frame(width: 560, height: 500)
    }
}
