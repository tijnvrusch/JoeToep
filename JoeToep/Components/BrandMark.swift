import SwiftUI

struct BrandMark: View {
    var compact = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: compact ? 20 : 23, weight: .semibold))
                .foregroundStyle(Color(red: 1, green: 0, blue: 0))
            if !compact {
                VStack(alignment: .leading, spacing: 0) {
                    Text("JoeToep").font(.system(size: 12, weight: .semibold, design: .rounded))
                    Text("#yolo").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("JoeToep, YouTube Home")
    }
}
