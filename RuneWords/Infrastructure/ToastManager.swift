//
//  ToastManager.swift
//  RuneWords
//
//  WO-004: Centralized toast/alert system for error handling and nil safety
//

import SwiftUI
import Combine

// MARK: - Toast Types

enum ToastType {
    case error
    case warning
    case info
    case success
    
    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .success: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: TimeInterval
    let action: ToastAction?
    
    init(message: String, type: ToastType, duration: TimeInterval = 3.0, action: ToastAction? = nil) {
        self.message = message
        self.type = type
        self.duration = duration
        self.action = action
    }
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastAction {
    let title: String
    let action: () -> Void
}

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var toasts: [ToastMessage] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public API
    
    func show(_ message: String, type: ToastType, duration: TimeInterval = 3.0, action: ToastAction? = nil) {
        let toast = ToastMessage(message: message, type: type, duration: duration, action: action)
        toasts.append(toast)
        
        // WO-007: Announce to VoiceOver
        UIAccessibility.post(notification: .announcement, argument: message)
        
        // Auto-dismiss after duration
        Timer.publish(every: duration, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { [weak self] _ in
                self?.dismiss(toast)
            }
            .store(in: &cancellables)
    }
    
    func showError(_ message: String, duration: TimeInterval = 4.0) {
        show(message, type: .error, duration: duration)
    }
    
    func showWarning(_ message: String, duration: TimeInterval = 3.0) {
        show(message, type: .warning, duration: duration)
    }
    
    func showInfo(_ message: String, duration: TimeInterval = 2.0) {
        show(message, type: .info, duration: duration)
    }
    
    func showSuccess(_ message: String, duration: TimeInterval = 2.0) {
        show(message, type: .success, duration: duration)
    }
    
    func dismiss(_ toast: ToastMessage) {
        toasts.removeAll { $0.id == toast.id }
    }
    
    func dismissAll() {
        toasts.removeAll()
        cancellables.removeAll()
    }
    
    // MARK: - Guardrail Methods (WO-004)
    
    /// Safe unwrapping with toast feedback
    func safeUnwrap<T>(_ optional: T?, fallback: T, errorMessage: String) -> T {
        guard let value = optional else {
            showError(errorMessage)
            return fallback
        }
        return value
    }
    
    /// Safe force unwrap with detailed error reporting
    func forceUnwrap<T>(_ optional: T?, context: String, file: String = #file, line: Int = #line) -> T? {
        guard let value = optional else {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            showError("Critical error in \(fileName):\(line) - \(context)")
            #if DEBUG
            print("🚨 FORCE UNWRAP FAILURE: \(context) at \(fileName):\(line)")
            #endif
            return nil
        }
        return value
    }
    
    /// Safe cast with toast feedback
    func safeCast<T>(_ value: Any, to type: T.Type, context: String) -> T? {
        guard let result = value as? T else {
            showError("Type casting failed: \(context)")
            #if DEBUG
            print("🚨 CAST FAILURE: Expected \(type), got \(Swift.type(of: value)) - \(context)")
            #endif
            return nil
        }
        return result
    }
    
    /// Validate remote config with fallback
    func validateRemoteConfig<T>(_ value: T?, key: String, fallback: T) -> T {
        guard let configValue = value else {
            showWarning("Using default for \(key) - remote config unavailable")
            return fallback
        }
        return configValue
    }
    
    /// Font loading with fallback
    func validateFont(name: String, size: CGFloat) -> Font {
        // Check if custom font is available
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        } else {
            showWarning("Custom font '\(name)' unavailable, using system font")
            return .system(size: size, weight: .medium, design: .default)
        }
    }
    
    /// Network/Firestore error handling
    func handleNetworkError(_ error: Error, context: String) {
        let message = "Network error: \(context) - \(error.localizedDescription)"
        showError(message, duration: 5.0)
        
        #if DEBUG
        print("🌐 NETWORK ERROR: \(message)")
        print("  Full error: \(error)")
        #endif
    }
    
    /// Ad loading error handling
    func handleAdError(_ error: Error, adType: String) {
        let message = "Ad loading failed: \(adType)"
        showWarning(message)
        
        #if DEBUG
        print("📺 AD ERROR: \(message) - \(error.localizedDescription)")
        #endif
    }
}

// MARK: - Toast View

private struct RWToastView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
                .font(.system(size: 20, weight: .semibold))
            
            // Message
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Action button (if provided)
            if let action = toast.action {
                Button(action.title) {
                    action.action()
                    onDismiss()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(toast.type.color)
            }
            
            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(toast.type.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .offset(y: offset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                offset = 0
                opacity = 1
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -50 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            offset = -100
                            opacity = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    }
                }
        )
        .onTapGesture {
            if toast.action != nil {
                toast.action?.action()
                onDismiss()
            }
        }
    }
}

// MARK: - Toast Container

struct ToastContainer: View {
    @StateObject private var toastManager = ToastManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(toastManager.toasts.prefix(3))) { toast in
                RWToastView(toast: toast) {
                    toastManager.dismiss(toast)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: toastManager.toasts.count)
    }
}

// MARK: - View Extension

extension View {
    func withToasts() -> some View {
        ZStack {
            self
            
            VStack {
                ToastContainer()
                Spacer()
            }
        }
    }
}
