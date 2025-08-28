//
//  Log.swift
//  RuneWords
//
//  Structured logging system using os.Logger with automatic stripping in Release

import Foundation
import os.log

/// Centralized logging system with category-based organization
public struct Log {
    
    // MARK: - Log Categories
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.runewords.app"
    
    /// Logger for game logic and gameplay
    static let game = Logger(subsystem: subsystem, category: "Game")
    
    /// Logger for ad-related events
    static let ads = Logger(subsystem: subsystem, category: "Ads")
    
    /// Logger for in-app purchases
    static let iap = Logger(subsystem: subsystem, category: "IAP")
    
    /// Logger for network operations
    static let network = Logger(subsystem: subsystem, category: "Network")
    
    /// Logger for UI/UX events
    static let ui = Logger(subsystem: subsystem, category: "UI")
    
    /// Logger for analytics events
    static let analytics = Logger(subsystem: subsystem, category: "Analytics")
    
    /// Logger for level and content loading
    static let content = Logger(subsystem: subsystem, category: "Content")
    
    /// Logger for performance metrics
    static let performance = Logger(subsystem: subsystem, category: "Performance")
    
    /// Logger for general app lifecycle
    static let app = Logger(subsystem: subsystem, category: "App")
    
    /// Logger for debugging (stripped in release)
    static let debug = Logger(subsystem: subsystem, category: "Debug")
    
    // MARK: - Shorthand Methods (for compatibility)
    
    /// Shorthand for debug logging
    public static func d(_ message: String, category: Logger? = nil) {
        let category = category ?? debug
        debug(message, category: category)
    }
    
    /// Shorthand for error logging
    public static func e(_ message: String, category: Logger? = nil) {
        let category = category ?? app
        error(message, category: category)
    }
    
    // MARK: - Logging Methods
    
    /// Log debug information (automatically stripped in Release builds)
    public static func debug(
        _ message: String,
        category: Logger? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let category = category ?? debug
        category.debug("[\(extractFileName(file)):\(line)] \(function) - \(message)")
        #endif
    }
    
    /// Log general information
    public static func info(
        _ message: String,
        category: Logger? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let category = category ?? app
        #if DEBUG
        category.info("[\(extractFileName(file)):\(line)] \(message)")
        #else
        // In release, only log important info
        category.info("\(message)")
        #endif
    }
    
    /// Log warnings
    public static func warning(
        _ message: String,
        category: Logger? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let category = category ?? app
        category.warning("⚠️ [\(extractFileName(file)):\(line)] \(message)")
    }
    
    /// Log errors
    public static func error(
        _ message: String,
        error: Error? = nil,
        category: Logger? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let category = category ?? app
        if let error = error {
            category.error("❌ [\(extractFileName(file)):\(line)] \(message) - Error: \(error.localizedDescription, privacy: .public)")
        } else {
            category.error("❌ [\(extractFileName(file)):\(line)] \(message)")
        }
    }
    
    /// Log critical/fatal errors
    public static func critical(
        _ message: String,
        error: Error? = nil,
        category: Logger? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let category = category ?? app
        if let error = error {
            category.critical("🔥 [\(extractFileName(file)):\(line)] CRITICAL: \(message) - Error: \(error.localizedDescription, privacy: .public)")
        } else {
            category.critical("🔥 [\(extractFileName(file)):\(line)] CRITICAL: \(message)")
        }
    }
    
    // MARK: - Category-Specific Convenience Methods
    
    /// Log game events
    public static func game(_ message: String, level: OSLogType = .info) {
        logWithLevel(message, category: game, level: level)
    }
    
    /// Log ad events
    public static func ads(_ message: String, level: OSLogType = .info) {
        logWithLevel(message, category: ads, level: level)
    }
    
    /// Log IAP events
    public static func iap(_ message: String, level: OSLogType = .info) {
        logWithLevel(message, category: iap, level: level)
    }
    
    /// Log network events
    public static func network(_ message: String, level: OSLogType = .info) {
        logWithLevel(message, category: network, level: level)
    }
    
    /// Log UI events
    public static func ui(_ message: String, level: OSLogType = .info) {
        logWithLevel(message, category: ui, level: level)
    }
    
    /// Log performance metrics
    public static func performance(_ message: String, level: OSLogType = .info) {
        #if DEBUG
        logWithLevel(message, category: performance, level: level)
        #else
        // Only log performance issues in release
        if level == .error || level == .fault {
            logWithLevel(message, category: performance, level: level)
        }
        #endif
    }
    
    // MARK: - Privacy-Aware Logging
    
    /// Log with privacy for sensitive data
    public static func logPrivate<T>(
        _ message: String,
        value: T,
        category: Logger? = nil
    ) {
        let category = category ?? app
        #if DEBUG
        category.info("\(message): \(String(describing: value), privacy: .private)")
        #else
        category.info("\(message): <redacted>")
        #endif
    }
    
    /// Log with public visibility (for non-sensitive data)
    public static func logPublic<T>(
        _ message: String,
        value: T,
        category: Logger? = nil
    ) {
        let category = category ?? app
        category.info("\(message): \(String(describing: value), privacy: .public)")
    }
    
    // MARK: - Performance Logging
    
    /// Measure and log execution time
    public static func measureTime<T>(
        operation: String,
        category: Logger? = nil,
        block: () throws -> T
    ) rethrows -> T {
        let category = category ?? performance
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            #if DEBUG
            category.info("⏱ \(operation) took \(String(format: "%.3f", timeElapsed))s")
            #else
            // Only log slow operations in release
            if timeElapsed > 0.5 {
                category.warning("⏱ Slow operation: \(operation) took \(String(format: "%.3f", timeElapsed))s")
            }
            #endif
        }
        return try block()
    }
    
    /// Async version of measureTime
    public static func measureTimeAsync<T>(
        operation: String,
        category: Logger? = nil,
        block: () async throws -> T
    ) async rethrows -> T {
        let category = category ?? performance
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            #if DEBUG
            category.info("⏱ \(operation) took \(String(format: "%.3f", timeElapsed))s")
            #else
            // Only log slow operations in release
            if timeElapsed > 0.5 {
                category.warning("⏱ Slow operation: \(operation) took \(String(format: "%.3f", timeElapsed))s")
            }
            #endif
        }
        return try await block()
    }
    
    // MARK: - Helper Methods
    
    private static func extractFileName(_ filePath: String) -> String {
        return URL(fileURLWithPath: filePath).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
    }
    
    private static func logWithLevel(
        _ message: String,
        category: Logger,
        level: OSLogType
    ) {
        switch level {
        case .debug:
            #if DEBUG
            category.debug("\(message)")
            #endif
        case .info:
            category.info("\(message)")
        case .error:
            category.error("\(message)")
        case .fault:
            category.fault("\(message)")
        default:
            category.log("\(message)")
        }
    }
}

// MARK: - SwiftUI View Modifier for Debug Logging

import SwiftUI

struct LoggingModifier: ViewModifier {
    let message: String
    let category: Logger
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                Log.debug("\(message) - appeared", category: category)
            }
            .onDisappear {
                Log.debug("\(message) - disappeared", category: category)
            }
    }
}

extension View {
    /// Add debug logging to view lifecycle
    func logged(_ message: String, category: Logger? = nil) -> some View {
        let category = category ?? Log.ui
        #if DEBUG
        return self.modifier(LoggingModifier(message: message, category: category))
        #else
        return self
        #endif
    }
}

// MARK: - Notification Logging

extension Notification.Name {
    /// Log when notifications are posted
    func logPost(object: Any? = nil) {
        #if DEBUG
        Log.debug("📮 Posted notification: \(self.rawValue)", category: Log.app)
        #endif
    }
}

// MARK: - Error Extensions

extension Error {
    /// Log this error with context
    func log(
        message: String = "Error occurred",
        category: Logger? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        Log.error(message, error: self, category: category, file: file, function: function, line: line)
    }
}
