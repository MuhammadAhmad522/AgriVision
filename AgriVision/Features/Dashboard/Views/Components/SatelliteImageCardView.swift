import SwiftUI

struct SatelliteImageCardView: View {
    let imageData: Data?

    var body: some View {
        LiquidGlassCard {
            ZStack(alignment: .bottomLeading) {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.12)
                    Image(systemName: "photo").textStyle(.display).foregroundStyle(.secondary)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text("True color").textStyle(.captionStrong)
                    Text(imageData == nil ? "Image pending" : "Latest satellite scene").textStyle(.caption)
                }
                .foregroundStyle(.white)
                .padding(14)
            }
        }
    }
}
