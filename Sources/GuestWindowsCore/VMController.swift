import Foundation

public enum VMStatus: String {
    case stopped = "Stopped"
    case starting = "Starting"
    case running = "Running"
    case error = "Error"
}

public struct LogEntry: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let message: String

    public init(_ message: String) {
        self.timestamp = Date()
        self.message = message
    }
}

/// Owns VM lifecycle and configuration. Today this is an honest scaffold:
/// it manages real app state (status, logs, settings) but does not yet
/// drive an actual CPU core, because that core doesn't exist yet
/// (see Milestone 2 onward). It must never claim to be running Windows
/// when it is not.
@MainActor
public final class VMController: ObservableObject {
    @Published public private(set) var status: VMStatus = .stopped
    @Published public private(set) var logs: [LogEntry] = []
    @Published public var ramMB: Int = 512
    @Published public var cpuCoreCount: Int = 1
    @Published public private(set) var serverAddress: String = "http://127.0.0.1:8080"
    @Published public private(set) var hasImportedISO: Bool = false
    @Published public private(set) var hasVirtualDisk: Bool = false
    @Published public private(set) var diskUsageBytes: Int64 = 0

    public init() {
        log("Guest Windows scaffold initialized. Emulator core not yet implemented (Milestone 2+).")
    }

    public func log(_ message: String) {
        logs.append(LogEntry(message))
        if logs.count > 500 {
            logs.removeFirst(logs.count - 500)
        }
    }

    public func importISO(at url: URL) {
        // Real ISO import / validation arrives with disk + boot milestones.
        hasImportedISO = true
        log("ISO reference recorded: \(url.lastPathComponent). Boot support not implemented yet.")
    }

    public func createVirtualDisk(sizeMB: Int) {
        hasVirtualDisk = true
        diskUsageBytes = 0
        log("Virtual disk descriptor created (\(sizeMB) MB requested). Storage controller not implemented yet.")
    }

    public func startWindows() {
        guard status != .running else { return }
        status = .starting
        log("Start requested. No CPU core is wired up yet, so this cannot boot anything real.")
        // Intentionally does not fake a transition to .running.
        // Once CPU.swift / the device layer exist, this will actually
        // initialize them and only report .running when they are.
        status = .error
        log("Halted: emulator core is not yet implemented. See README milestones.")
    }

    public func stopWindows() {
        status = .stopped
        log("Stop requested. (No-op: nothing was running.)")
    }
}
