import SwiftUI
import MapKit

/// The visual overview for the Fields tab.
///
/// This view intentionally receives display data from the existing dashboard flow. Map editing,
/// field creation, and detail routing remain coordinator responsibilities for a later iteration.
struct FieldsView: View {
    let field: Field?
    let profileImageURL: URL?
    let profileInitial: String

    @State private var cameraPosition: MapCameraPosition = .region(Self.initialRegion)

    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 31.5204, longitude: 74.3587),
        span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
    )

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                if fieldBoundary.count >= 3 {
                    MapPolygon(coordinates: fieldBoundary)
                        .foregroundStyle(AppColors.limeGreen.opacity(0.42))
                        .stroke(AppColors.charcoalGreen, lineWidth: 2)
                }

                if let fieldCenter {
                    Annotation("Field center", coordinate: fieldCenter) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white, lineWidth: 4))
                            .shadow(radius: 3)
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .mapControls {
                MapCompass()
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.28), .clear, .black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                fieldsHeader
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                HStack(alignment: .bottom) {
                    mapButton(systemImage: "plus", accessibilityLabel: "Add field") {
                        // TODO: Route to the add-field flow through FieldSelectionCoordinator.
                    }

                    Spacer()

                    mapButton(systemImage: "location.fill", accessibilityLabel: "Recenter map") {
                        withAnimation(.easeInOut) {
                            cameraPosition = .region(fieldRegion ?? Self.initialRegion)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 18)

                fieldSummaryCard
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }

            ndviLegend
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 18)
                .offset(y: -120)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: field?.id) {
            cameraPosition = .region(fieldRegion ?? Self.initialRegion)
        }
    }

    private var fieldsHeader: some View {
        HStack(spacing: 12) {
            Label("Lahore, Punjab", systemImage: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.darkCoal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.72), lineWidth: 1))

            profileAvatar
        }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let profileImageURL {
            AsyncImage(url: profileImageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ProgressView()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
        } else {
            Circle()
                .fill(AppColors.mediumGreen)
                .frame(width: 46, height: 46)
                .overlay {
                    Text(profileInitial.isEmpty ? "A" : profileInitial)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .overlay(Circle().stroke(.white, lineWidth: 2))
        }
    }

    private var ndviLegend: some View {
        HStack(spacing: 7) {
            Text(String(format: "%.2f", healthScore))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.charcoalGreen)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))

            LinearGradient(
                colors: [.red, .orange, .yellow, .green],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(width: 12, height: 116)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.7), lineWidth: 1))
        }
    }

    private var fieldSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.title2.weight(.bold))
                    Text("Lahore, Punjab")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(coordinateDescription)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mediumGreen)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                fieldFact(label: "Area", value: areaDescription)
                fieldFact(label: "Crop Type", value: cropType)
                fieldFact(label: "Sensors Integrated", value: "3")
                fieldFact(label: "Last Updated", value: lastUpdatedDescription)
            }

            Divider()

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Health: \(healthLabel) (\(Int(healthScore * 100))%)")
                        .font(.subheadline.weight(.semibold))

                    ProgressView(value: healthScore)
                        .tint(AppColors.mediumGreen)
                }

                Spacer()

                Button {
                    // TODO: Route to field details through the coordinator.
                } label: {
                    Label("View Details", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(AppColors.charcoalGreen)
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 16, y: 8)
    }

    private func fieldFact(label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text("\(label):")
                .fontWeight(.semibold)
            Text(value)
        }
        .font(.subheadline)
    }

    private func mapButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title.weight(.semibold))
                .frame(width: 54, height: 54)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .tint(AppColors.mediumGreen)
        .accessibilityLabel(accessibilityLabel)
    }

    private var displayName: String {
        field?.name ?? "Rice Field"
    }

    private var fieldBoundary: [CLLocationCoordinate2D] {
        field?.coordinates?.map(\.coordinate) ?? []
    }

    private var fieldCenter: CLLocationCoordinate2D? {
        guard !fieldBoundary.isEmpty else { return nil }

        let total = fieldBoundary.reduce((latitude: 0.0, longitude: 0.0)) { result, coordinate in
            (
                latitude: result.latitude + coordinate.latitude,
                longitude: result.longitude + coordinate.longitude
            )
        }

        return CLLocationCoordinate2D(
            latitude: total.latitude / Double(fieldBoundary.count),
            longitude: total.longitude / Double(fieldBoundary.count)
        )
    }

    private var fieldRegion: MKCoordinateRegion? {
        guard let firstCoordinate = fieldBoundary.first else { return nil }

        let bounds = fieldBoundary.dropFirst().reduce(
            (minLatitude: firstCoordinate.latitude,
             maxLatitude: firstCoordinate.latitude,
             minLongitude: firstCoordinate.longitude,
             maxLongitude: firstCoordinate.longitude)
        ) { bounds, coordinate in
            (
                min(bounds.minLatitude, coordinate.latitude),
                max(bounds.maxLatitude, coordinate.latitude),
                min(bounds.minLongitude, coordinate.longitude),
                max(bounds.maxLongitude, coordinate.longitude)
            )
        }

        let center = CLLocationCoordinate2D(
            latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
            longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((bounds.maxLatitude - bounds.minLatitude) * 1.7, 0.0015),
            longitudeDelta: max((bounds.maxLongitude - bounds.minLongitude) * 1.7, 0.0015)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    private var coordinateDescription: String {
        guard let fieldCenter else { return "--, --" }
        return String(format: "%.4f, %.4f", fieldCenter.latitude, fieldCenter.longitude)
    }

    private var cropType: String {
        field?.cropType ?? "Rice"
    }

    private var areaDescription: String {
        guard let areaHa = field?.areaHa else { return "2.5 Acres" }
        return String(format: "%.1f Acres", areaHa * 2.47105)
    }

    private var healthScore: Double {
        min(max(field?.ndviScore ?? 0.88, 0), 1)
    }

    private var healthLabel: String {
        switch healthScore {
        case 0.7...1: return "Good"
        case 0.4..<0.7: return "Fair"
        default: return "Needs Attention"
        }
    }

    private var lastUpdatedDescription: String {
        guard let lastSync = field?.lastSatelliteSync else { return "35 min ago" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}

#Preview {
    FieldsView(
        field: nil,
        profileImageURL: nil,
        profileInitial: "A"
    )
}
