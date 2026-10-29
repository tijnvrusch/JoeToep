import Foundation
import Combine
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    enum State: Equatable {
        case checking
        case online(expensive: Bool, constrained: Bool)
        case offline

        var isOnline: Bool {
            if case .online = self { return true }
            return false
        }

        var label: String {
            switch self {
            case .checking: "Checking"
            case let .online(expensive, constrained):
                if constrained { "Low Data"
                } else if expensive { "Cellular"
                } else { "Online" }
            case .offline: "Offline"
            }
        }

        var symbolName: String {
            switch self {
            case .checking: "network"
            case .online: "wifi"
            case .offline: "wifi.slash"
            }
        }
    }

    @Published private(set) var state: State = .checking

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "nl.tijn.joetoep.network", qos: .utility)

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let next: State = path.status == .satisfied
                ? .online(expensive: path.isExpensive, constrained: path.isConstrained)
                : .offline
            Task { @MainActor [weak self] in
                self?.state = next
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
