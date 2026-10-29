import SwiftUI

struct ConnectionPill: View {
    let state: NetworkMonitor.State
    let isLoading: Bool
    let isBuffering: Bool
    let resolution: String?

    var body: some View {
        HStack(spacing: 7) {
            if isLoading || isBuffering {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: state.symbolName)
                    .foregroundStyle(state.isOnline ? Color.mint : Color.orange)
            }

            Text(isBuffering ? "Buffering" : state.label)
                .font(.caption.weight(.medium))

            if let resolution {
                Divider()
                    .frame(height: 12)
                Text(resolution)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .joeToepGlass(in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

