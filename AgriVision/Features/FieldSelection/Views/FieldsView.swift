import MapKit
import SwiftUI
import UIKit

struct FieldsView: View {
    @ObservedObject var fieldStore: FieldSessionStore
    let satellite: SourceState<SatelliteSnapshot>?
    let satelliteImageData: Data?
    let sensorCount: Int
    let profileImageURL: URL?
    let profileInitial: String
    let onAddField: () -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                if boundary.count >= 3 {
                    MapPolygon(coordinates: boundary)
                        .foregroundStyle(AppColors.limeGreen.opacity(0.38))
                        .stroke(AppColors.charcoalGreen, lineWidth: 2)
                }
                if let center {
                    Annotation("Field center", coordinate: center) {
                        Circle().fill(.blue).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea()

            if let satelliteImageData, let image = UIImage(data: satelliteImageData), activeField != nil {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.24)
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Latest cached NDVI overlay")
            }

            LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                header.padding(.horizontal).padding(.top, 8)
                Spacer()
                HStack {
                    Button(action: onAddField) {
                        Image(systemName: "plus").font(.title2.bold()).frame(width: 52, height: 52)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(AppColors.mediumGreen)
                    .disabled(fieldStore.hasReachedLimit)
                    .accessibilityLabel(fieldStore.hasReachedLimit ? "Five-field limit reached" : "Add field")
                    Spacer()
                    Button {
                        cameraPosition = .region(region ?? Self.fallbackRegion)
                    } label: {
                        Image(systemName: "location.fill").font(.title2).frame(width: 52, height: 52)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(AppColors.mediumGreen)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 12)

                summaryCard
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: fieldStore.activeFieldId) { cameraPosition = .region(region ?? Self.fallbackRegion) }
        .simultaneousGesture(
            DragGesture(minimumDistance: 60).onEnded { gesture in
                guard abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                if gesture.translation.width < 0 {
                    fieldStore.selectNext()
                } else {
                    fieldStore.selectPrevious()
                }
            }
        )
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(activeField?.name ?? "No active field").font(.headline)
                Text(fieldStore.fields.isEmpty ? "Register your first field" : "Field \(currentIndex + 1) of \(fieldStore.fields.count)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            avatar
        }
    }

    @ViewBuilder private var avatar: some View {
        if let profileImageURL {
            AsyncImage(url: profileImageURL) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
                .frame(width: 46, height: 46).clipShape(Circle())
        } else {
            Circle().fill(AppColors.mediumGreen).frame(width: 46, height: 46)
                .overlay(Text(profileInitial.isEmpty ? "U" : profileInitial).foregroundStyle(.white).bold())
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: fieldStore.selectPrevious) { Image(systemName: "chevron.left") }
                    .disabled(currentIndex == 0)
                Spacer()
                VStack {
                    Text(activeField?.name ?? "No field selected").font(.title3.bold())
                    Text(coordinateDescription).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: fieldStore.selectNext) { Image(systemName: "chevron.right") }
                    .disabled(fieldStore.fields.isEmpty || currentIndex >= fieldStore.fields.count - 1)
            }
            Divider()
            if let field = activeField {
                fact("Area", field.areaHa.map { String(format: "%.2f ha", $0) } ?? "Unavailable")
                fact("Crop", field.cropType ?? "Not set")
                fact("Sensors", "\(sensorCount)")
                fact("Satellite", satellite?.status.capitalized ?? field.agroStatus.capitalized)
                fact("NDVI", field.ndviScore.map { String(format: "%.2f", $0) } ?? "Pending")
                if let message = field.agroError { Text(message).font(.caption).foregroundStyle(.orange) }
            } else {
                Text("Use the plus button to register a field.").foregroundStyle(.secondary)
            }
            if fieldStore.hasReachedLimit {
                Text("Five fields reached. Delete one before adding another.")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .foregroundStyle(AppColors.charcoalGreen)
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack { Text(label).fontWeight(.semibold); Spacer(); Text(value) }.font(.subheadline)
    }

    private var activeField: Field? { fieldStore.activeField }
    private var currentIndex: Int { fieldStore.fields.firstIndex(where: { $0.id == fieldStore.activeFieldId }) ?? 0 }
    private var boundary: [CLLocationCoordinate2D] { activeField?.coordinates?.map(\.coordinate) ?? [] }
    private var center: CLLocationCoordinate2D? {
        guard !boundary.isEmpty else { return nil }
        let sum = boundary.reduce((0.0, 0.0)) { ($0.0 + $1.latitude, $0.1 + $1.longitude) }
        return .init(latitude: sum.0 / Double(boundary.count), longitude: sum.1 / Double(boundary.count))
    }
    private var coordinateDescription: String { center.map { String(format: "%.4f, %.4f", $0.latitude, $0.longitude) } ?? "Coordinates unavailable" }
    private var region: MKCoordinateRegion? {
        guard let first = boundary.first else { return nil }
        let lats = boundary.map(\.latitude), lons = boundary.map(\.longitude)
        let minLat = lats.min() ?? first.latitude, maxLat = lats.max() ?? first.latitude
        let minLon = lons.min() ?? first.longitude, maxLon = lons.max() ?? first.longitude
        return .init(center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2), span: .init(latitudeDelta: max((maxLat - minLat) * 1.7, 0.002), longitudeDelta: max((maxLon - minLon) * 1.7, 0.002)))
    }
    private static let fallbackRegion = MKCoordinateRegion(center: .init(latitude: 31.5204, longitude: 74.3587), span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02))
}
