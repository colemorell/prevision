import AVFoundation
import Combine
import SwiftUI

nonisolated final class SessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.prevision.captureSessionController")
    private var configured = false

    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if configureIfNeeded(), !session.isRunning {
                    session.startRunning()
                }
                continuation.resume(returning: session.isRunning)
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if session.isRunning {
                    session.stopRunning()
                }
                continuation.resume()
            }
        }
    }

    private func configureIfNeeded() -> Bool {
        if configured {
            return true
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            return false
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            return false
        }

        session.beginConfiguration()
        session.sessionPreset = .low

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
        configured = true
        return true
    }
}

final class CaptureSessionController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var authorizationDenied = false
    @Published var accessoryAvailable = false

    private let box = SessionBox()
    var session: AVCaptureSession { box.session }
    private var notificationTasks: [Task<Void, Never>] = []

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                authorizationDenied = true
                return
            }
        case .denied, .restricted:
            authorizationDenied = true
            return
        @unknown default:
            authorizationDenied = true
            return
        }

        authorizationDenied = false
        observeSessionNotifications()

        isRunning = await box.start()
    }

    func stop() {
        let box = self.box
        Task {
            await box.stop()
        }
        isRunning = false
    }

    private func observeSessionNotifications() {
        guard notificationTasks.isEmpty else { return }

        let interrupted = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.wasInterruptedNotification) {
                self?.isRunning = false
            }
        }

        let interruptionEnded = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.interruptionEndedNotification) {
                guard let self else { continue }
                self.isRunning = self.box.session.isRunning
            }
        }

        let runtimeError = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification) {
                self?.isRunning = false
            }
        }

        notificationTasks = [interrupted, interruptionEnded, runtimeError]
    }

    deinit {
        for task in notificationTasks {
            task.cancel()
        }
    }
}
