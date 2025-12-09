//
//  AppLogger.swift
//  WorkScheduleApp
//
//  Wrapper simple autour de os.Logger pour centraliser les logs
//

import Foundation
import os

struct AppLogger {
    static let shared = AppLogger()

    private let logger: Logger

    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.davidguia.shifter"
        logger = Logger(subsystem: subsystem, category: "App")
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
