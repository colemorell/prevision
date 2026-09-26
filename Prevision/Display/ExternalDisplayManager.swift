import SwiftUI
import UIKit
import Combine

final class ExternalDisplayManager: ObservableObject {
    @Published var externalScreenConnected: Bool = false

    private var screenConnectCancellable: NSObjectProtocol?
    private var screenDisconnectCancellable: NSObjectProtocol?

    func startObserving() {
        screenConnectCancellable = NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.externalScreenConnected = true
        }

        screenDisconnectCancellable = NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.externalScreenConnected = false
        }
    }

    func stopObserving() {
        if let connect = screenConnectCancellable {
            NotificationCenter.default.removeObserver(connect)
        }
        if let disconnect = screenDisconnectCancellable {
            NotificationCenter.default.removeObserver(disconnect)
        }
        screenConnectCancellable = nil
        screenDisconnectCancellable = nil
    }
}
