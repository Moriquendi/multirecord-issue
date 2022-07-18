//
//  DevicesPicker.swift
//  MultiRecorder
//
//  Created by Michał Śmiałko on 18/07/2022.
//

import AVFoundation
import Combine
import Foundation
import SimplyCoreAudio
import SwiftUI

private class ViewModel: ObservableObject {
    @Published private(set) var outputDevices: [AudioDevice] = []
    @Published private(set) var inputDevices: [AudioDevice] = []
    
    private var sink: Any?
    private let session = SimplyCoreAudio()
    
    init() {
        // Observe all avaiable devices
        sink = NotificationCenter.default.publisher(for: NSNotification.Name.deviceListChanged)
            .map { _ in () }
            .prepend(())
            .sink { [weak self] _ in
                self?._reload()
            }
    }
    
    private func _reload() {
        inputDevices = session.allInputDevices
        outputDevices = session.allOutputDevices
    }
}

struct DevicesPicker: View {
    @Binding var selection: [AudioDevice]
    @StateObject private var model = ViewModel()
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                GroupBox("Input") {
                    listOf(devices: model.inputDevices)
                }
                GroupBox("Output") {
                    listOf(devices: model.outputDevices)
                }
            }
            .buttonStyle(.link)
        }
    }
    
    private func listOf(devices: [AudioDevice]) -> some View {
        VStack(alignment: .leading) {
            ForEach(devices, id: \.self) { device in
                let isSelected = selection.contains(device)
                Button(action: {
                    if isSelected {
                        selection.removeAll { $0 == device }
                    } else {
                        selection.append(device)
                    }
                }) {
                    Label(device.name, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.link)
            }
        }
    }
}
