#if os(iOS)
import SwiftUI
import AVKit
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = .white
        picker.activeTintColor = .systemRed
        picker.accessibilityLabel = "AirPlay"
        picker.accessibilityIdentifier = "toolbar.airplay"
        return picker
    }
    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}
#endif
