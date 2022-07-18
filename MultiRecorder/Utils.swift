//
//  Utils.swift
//  MultiRecorder
//
//  Created by Michał Śmiałko on 18/07/2022.
//

import Foundation

public extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
