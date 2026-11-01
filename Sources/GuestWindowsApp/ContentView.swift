import SwiftUI
import GuestWindowsCore
import UniformTypeIdentifiers

private enum Theme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.09)
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.14)
    static let accent = Color(red: 0.58, green: 0.42, blue: 0.93) // purple
    static let accentDim = Color(red: 0.58, green: 0.42, blue: 0.93).opacity(0.35)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
}

struct ContentView: View {
    @EnvironmentObject private var vm: VMController
    @State private var showingISOPicker = false
    @State private var newDiskSizeMB: Double = 20000

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    statusCard
                    controlsCard
                    settingsCard
                    storageCard
                    serverCard
                    logCard
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Guest Windows")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(Theme.accent)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "pc")
                .font(.system(size: 28))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Guest Windows")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("Custom x86 emulator — local to this iPad")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var statusCard: some View {
        card(title: "Emulator Status") {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(vm.status.rawValue)
                    .foregroundStyle(Theme.textPrimary)
                    .fontWeight(.semibold)
                Spacer()
            }
            if vm.status == .error {
                Text("Core not implemented yet — see project milestones in the README.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var controlsCard: some View {
        card(title: "Controls") {
            HStack(spacing: 12) {
                Button {
                    vm.startWindows()
                } label: {
                    Label("Start Windows", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                Button {
                    vm.stopWindows()
                } label: {
                    Label("Stop Windows", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.4))
            }
        }
    }

    private var settingsCard: some View {
        card(title: "CPU & RAM Settings") {
            Stepper(value: $vm.cpuCoreCount, in: 1...4) {
                labeledValue("Virtual CPU cores", "\(vm.cpuCoreCount)")
            }
            Stepper(value: $vm.ramMB, in: 128...2048, step: 128) {
                labeledValue("RAM", "\(vm.ramMB) MB")
            }
        }
    }

    private var storageCard: some View {
        card(title: "ISO & Virtual Disk") {
            Button {
                showingISOPicker = true
            } label: {
                Label(vm.hasImportedISO ? "ISO imported" : "Import Windows 10 ISO…",
                      systemImage: "opticaldisc")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .fileImporter(isPresented: $showingISOPicker, allowedContentTypes: [.diskImage, .item]) { result in
                if case .success(let url) = result {
                    vm.importISO(at: url)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("New virtual disk size: \(Int(newDiskSizeMB)) MB")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                Slider(value: $newDiskSizeMB, in: 4000...64000, step: 1000)
                Button {
                    vm.createVirtualDisk(sizeMB: Int(newDiskSizeMB))
                } label: {
                    Label(vm.hasVirtualDisk ? "Disk created" : "Create virtual disk",
                          systemImage: "internaldrive")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }

            labeledValue("Disk usage", formattedBytes(vm.diskUsageBytes))
        }
    }

    private var serverCard: some View {
        card(title: "Local Server") {
            labeledValue("Address", vm.serverAddress)
            Button {
                if let url = URL(string: vm.serverAddress) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open in Safari", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .disabled(vm.status != .running)

            if vm.status != .running {
                Text("Disabled until the emulator is actually running.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var logCard: some View {
        card(title: "Logs") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(vm.logs.suffix(20)) { entry in
                    Text("[\(entry.timestamp.formatted(date: .omitted, time: .standard))] \(entry.message)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch vm.status {
        case .running: return .green
        case .starting: return .yellow
        case .error: return .red
        case .stopped: return .gray
        }
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary).fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            content()
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.accentDim, lineWidth: 1)
        )
    }
}

#Preview {
    ContentView().environmentObject(VMController())
}
