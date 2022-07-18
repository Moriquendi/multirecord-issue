//
//  Recorder.swift
//  MultiRecorder
//
//  Created by Michał Śmiałko on 18/07/2022.
//

import AVFoundation
import Combine
import Foundation
import SimplyCoreAudio

class Recorder: ObservableObject {
    let AGGREGATE_DEVICE_ID = "RecorderAggregate"
    
    @Published var selectedDevices: [AudioDevice] = []
    @Published private(set) var isRecording = false
    @Published private(set) var recordedTime: TimeInterval = 0.0
    @Published private(set) var error: Error?
    
    private var sinks = Set<AnyCancellable>()
    private var avEngine: AVAudioEngine?
    
    init() {
        //
        // Observe when AVAudioEngine changes its configuration
        // and thus is stopped.
        // An error will be shown in UI when configuration is changed after starting the engine.
        //
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange)
            .sink { [weak self] noti in
                guard let self = self, (noti.object as? AVAudioEngine) === self.avEngine else { return }
                print("[⚠️] Engine configuration changed.")
                DispatchQueue.main.async {
                    self.handleInterruption()
                }
            }
            .store(in: &sinks)
    }
    
    /// Starts / Stops recording via AVAudioEngine
    func toggle() {
        error = nil
        
        if isRecording {
            stop()
        } else {
            Task {
                await self.start()
            }
        }
    }
}

extension Recorder {
    @MainActor
    private func start() async {
        print("[ℹ️] Configure engine...")
        // Create a new AVAudioEngine
        let engine = AVAudioEngine()
        avEngine = engine
        
        // Create 'Aggregate Device' with selected input devices and a single output device.
        let subdevicesIds = selectedDevices.map { $0.uid! }
        print("[ℹ️] Create aggregate device: \(subdevicesIds)")
        let deviceID = try! createAggregateDevice(devicesUIDs: subdevicesIds)
        
        // Make sure the new device is a system's default for both input and output.
        let aggregateDevice = AudioDevice.lookup(by: deviceID)
        aggregateDevice?.isDefaultInputDevice = true
        aggregateDevice?.isDefaultOutputDevice = true
        
        // Sleep to make sure aggregate device is created and set as default
        try! await Task.sleep(seconds: 1.0)
        
        // Install tap on input device and track how many frames were recorded.
        let inputNode = engine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            let duration = Double(buffer.frameLength) / buffer.format.sampleRate
            DispatchQueue.main.async { [weak self] in
                guard self?.isRecording ?? false else { return }
                self?.recordedTime += duration
            }
        }
        
        // Create a simply nodes graph.
        let someMixerNode = AVAudioMixerNode()
        engine.attach(someMixerNode)
        engine.connect(inputNode, to: someMixerNode, format: nil)
        engine.connect(someMixerNode, to: engine.mainMixerNode, format: inputNode.outputFormat(forBus: 0))
        
        // Mute volume on output device.
        engine.mainMixerNode.outputVolume = 0.0
        
        // Prepare engine and start it.
        engine.prepare()
        try! engine.start()
        print("[ℹ️] Engine started.")
        isRecording = true
    }
    
    private func stop() {
        avEngine?.stop()
        avEngine = nil
        recordedTime = 0.0
        isRecording = false
        destroyOldAggregateDevice()
    }
    
    private func handleInterruption() {
        guard let engine = avEngine else { return }
        if !engine.isRunning {
            stop()
            error = NSError(domain: "app", code: -1, userInfo: [NSLocalizedDescriptionKey: "AVAudioEngine was interrupted."])
        }
    }
    
    private func createAggregateDevice(devicesUIDs: [String]) throws -> AudioDeviceID {
        let masterDeviceID = devicesUIDs[0]
        
        let subDevicesList: [[String: Any]] = devicesUIDs.map { uid in
            [
                kAudioSubDeviceUIDKey: uid as CFString,
            ]
        }
        
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Pompom Input",
            kAudioAggregateDeviceUIDKey: AGGREGATE_DEVICE_ID,
            kAudioAggregateDeviceSubDeviceListKey: subDevicesList,
            kAudioAggregateDeviceMasterSubDeviceKey: masterDeviceID as CFString,
            kAudioAggregateDeviceClockDeviceKey: masterDeviceID as CFString,
            // kAudioAggregateDeviceIsPrivateKey: 1 as CFNumber
        ]
        
        var aggregateDeviceId: AudioDeviceID = 0
        let status = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggregateDeviceId)
        guard status == 0 else {
            destroyOldAggregateDevice()
            fatalError()
        }
        
        print("[ℹ️] Did create aggregate device. ID: \(aggregateDeviceId)")
        return aggregateDeviceId
    }
    
    private func destroyOldAggregateDevice() {
        let session = SimplyCoreAudio()
        let aggregateDevice = session.allAggregateDevices
            .first { $0.uid == AGGREGATE_DEVICE_ID }
        guard let aggregateDevice = aggregateDevice else { return }
        let status = session.removeAggregateDevice(id: aggregateDevice.id)
        print("[⏺] Destroy status: \(status)")
    }
}
