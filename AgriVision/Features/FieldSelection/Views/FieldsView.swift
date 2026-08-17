import MapKit
import SwiftUI
import UIKit

struct FieldsView: View {
    @ObservedObject var fieldStore: FieldSessionStore
    let satellite: SourceState<SatelliteSnapshot>?
    let satelliteImageData: Data?
    let sensorCount: Int
    let snapshotFieldId: UUID?
    let isLoadingSnapshot: Bool
    let profileImageURL: URL?
    let profileInitial: String
    let onAddField: () -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                if boundary.count >= 3 {
                    MapPolygon(coordinates: boundary)
                        .foregroundStyle(Theme.Colors.primaryLight.opacity(0.38))
                        .stroke(Theme.Colors.primary, lineWidth: 2)
                }
                if let center {
                    Annotation("Field center", coordinate: center) {
                        Circle().fill(.blue).frame(width: 16, height: 16).overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .ignoresSafeArea()

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
                    .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(Theme.Colors.primaryMedium)
                    .disabled(fieldStore.hasReachedLimit)
                    .accessibilityLabel(fieldStore.hasReachedLimit ? "Five-field limit reached" : "Add field")
                    Spacer()
                    Button {
                        cameraPosition = .region(region ?? Self.fallbackRegion)
                    } label: {
                        Image(systemName: "location.fill").font(.title2).frame(width: 52, height: 52)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(Theme.Colors.primaryMedium)
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 12)

                summaryCard
                    .id(activeField?.id)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: fieldStore.activeFieldId) { cameraPosition = .region(region ?? Self.fallbackRegion) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(activeField?.name ?? "No active field").textStyle(.bodyStrong)
                Text(fieldStore.fields.isEmpty ? "Register your first field" : "Field \(currentIndex + 1) of \(fieldStore.fields.count)")
                    .textStyle(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(Theme.Colors.creamColor, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            Spacer()
            avatar
        }
    }

    @ViewBuilder private var avatar: some View {
        if let profileImageURL {
            AsyncImage(url: profileImageURL) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
                .frame(width: 46, height: 46).clipShape(Circle())
        } else {
            Circle().fill(Theme.Colors.primaryMedium).frame(width: 46, height: 46)
                .overlay(Text(profileInitial.isEmpty ? "U" : profileInitial).foregroundStyle(.white).bold())
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: fieldStore.selectPrevious) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                    .disabled(currentIndex == 0)
                Spacer()
                VStack(spacing: 3) {
                    Text(activeField?.name ?? "No field selected").font(.title3.bold())
                    Text(coordinateDescription).textStyle(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: fieldStore.selectNext) {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                    .disabled(fieldStore.fields.isEmpty || currentIndex >= fieldStore.fields.count - 1)
            }
            Divider()
            if let field = activeField {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 9) {
                        fact("Area", field.areaHa.map { String(format: "%.2f ha", $0) } ?? "Unavailable")
                        fact("Crop", field.cropType ?? "Not set")
                        fact("Sensors", hasLiveSnapshot ? "\(sensorCount)" : (isLoadingSnapshot ? "Loading…" : "Unavailable"))
                        fact("Satellite", hasLiveSnapshot ? (satellite?.status.capitalized ?? field.agroStatus?.capitalized ?? "Pending") : (field.agroStatus?.capitalized ?? "Pending"))
                        fact("NDVI", field.ndviScore.map { String(format: "%.2f", $0) } ?? "Pending")
                    }
                    if hasLiveSnapshot, let satelliteImageData, let image = UIImage(data: satelliteImageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 78, height: 78)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.primaryLight.opacity(0.65)))
                            .accessibilityLabel("Latest cached NDVI image")
                    }
                }
                if let message = field.agroError { Text(message).textStyle(.caption).foregroundStyle(.orange) }
            } else {
                Text("Use the plus button to register a field.").foregroundStyle(.secondary)
            }
            if fieldStore.hasReachedLimit {
                Text("Five fields reached. Delete one before adding another.")
                    .textStyle(.caption).foregroundStyle(.orange)
            }
        }
        .foregroundStyle(Theme.Colors.primary)
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .fixedSize(horizontal: false, vertical: true)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack { Text(label).fontWeight(.semibold); Spacer(); Text(value) }.textStyle(.body)
    }

    private var activeField: Field? { fieldStore.activeField }
    private var hasLiveSnapshot: Bool { activeField?.id == snapshotFieldId }
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
