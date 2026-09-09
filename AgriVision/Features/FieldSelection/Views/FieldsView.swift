import FirebaseAuth
import MapKit
import SwiftUI
import UIKit

struct FieldsView: View {
    enum SatelliteLayer: String, CaseIterable, Identifiable {
        case ndvi = "NDVI"
        case ndwi = "Water"
        case evi = "EVI"
        case truecolor = "True Color"
        
        var id: String { self.rawValue }

        var shortName: String {
            switch self {
            case .ndvi: return "NDVI"
            case .ndwi: return "Water"
            case .evi: return "EVI"
            case .truecolor: return "True Color"
            }
        }
        
        var title: String {
            switch self {
            case .ndvi: return "NDVI Vegetation"
            case .ndwi: return "Canopy Moisture (NDWI)"
            case .evi: return "Enhanced Vegetation (EVI)"
            case .truecolor: return "True Color Satellite"
            }
        }

        var subtitle: String {
            switch self {
            case .ndvi: return "Crop health, chlorophyll & biomass"
            case .ndwi: return "Leaf water content & drought stress"
            case .evi: return "Atmosphere-corrected canopy density"
            case .truecolor: return "Natural optical high-res photography"
            }
        }

        var iconName: String {
            switch self {
            case .ndvi: return "leaf.fill"
            case .ndwi: return "drop.fill"
            case .evi: return "sparkles"
            case .truecolor: return "globe.americas.fill"
            }
        }

        var gradientColors: [Color] {
            switch self {
            case .ndvi: return [Color.green, Color(red: 0.1, green: 0.6, blue: 0.3)]
            case .ndwi: return [Color.cyan, Color.blue]
            case .evi: return [Color(red: 0.2, green: 0.85, blue: 0.55), Color(red: 0.05, green: 0.55, blue: 0.4)]
            case .truecolor: return [Color.orange, Color.purple]
            }
        }
    }

    @ObservedObject var fieldStore: FieldSessionStore
    let satellite: SourceState<SatelliteSnapshot>?
    let satelliteImageData: Data?
    let sensorCount: Int
    let snapshotFieldId: UUID?
    let isLoadingSnapshot: Bool
    let profileImageURL: URL?
    let profileInitial: String
    let onAddField: () -> Void
    let onSignOut: () -> Void

    @State private var region: MKCoordinateRegion = Self.fallbackRegion
    @State private var selectedLayer: SatelliteLayer = .ndvi
    @State private var isShowingLayerPicker: Bool = false

    var activeTileURL: String? {
        guard hasLiveSnapshot, let data = satellite?.data else { return nil }
        switch selectedLayer {
        case .ndvi: return data.ndviTileURL
        case .ndwi: return data.ndwiTileURL
        case .evi: return data.eviTileURL
        case .truecolor: return nil // Use high-res Apple Maps satellite instead of low-res Sentinel-2 truecolor
        }
    }

    var body: some View {
        ZStack {
            FieldMapView(
                boundary: boundary,
                centerCoordinate: center,
                fieldTitle: activeField?.name,
                satelliteImage: (hasLiveSnapshot && satelliteImageData != nil) ? UIImage(data: satelliteImageData!) : nil,
                tileURL: activeTileURL,
                healthColor: UIColor(healthColor),
                region: $region
            )
            .ignoresSafeArea()

            LinearGradient(colors: [.black.opacity(0.3), .clear, .black.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                header.padding(.horizontal).padding(.top, 8)
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    if hasLiveSnapshot && !isShowingLayerPicker {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isShowingLayerPicker = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: selectedLayer.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 24, height: 24)
                                    Image(systemName: selectedLayer.iconName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                Text(selectedLayer.shortName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.Colors.primary)
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 14) {
                        Button(action: onAddField) {
                            Image(systemName: "plus")
                                .font(.title3.bold())
                                .foregroundColor(Theme.Colors.primary)
                                .frame(width: 46, height: 46)
                        }
                        .buttonStyle(.plain)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                        .disabled(fieldStore.hasReachedLimit)
                        
                        Button {
                            if let newRegion = defaultRegion {
                                withAnimation(.easeInOut) {
                                    region = newRegion
                                }
                            }
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.title3)
                                .foregroundColor(Theme.Colors.primary)
                                .frame(width: 46, height: 46)
                        }
                        .buttonStyle(.plain)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)

                        if hasLiveSnapshot {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isShowingLayerPicker.toggle()
                                }
                            } label: {
                                Image(systemName: isShowingLayerPicker ? "xmark" : "square.3.layers.3d.down.right")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(isShowingLayerPicker ? .white : Theme.Colors.primary)
                                    .frame(width: 46, height: 46)
                            }
                            .buttonStyle(.plain)
                            .background {
                                if isShowingLayerPicker {
                                    Circle()
                                        .fill(LinearGradient(colors: [Theme.Colors.primaryMedium, Theme.Colors.primaryLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                                } else {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                }
                            }
                            .overlay(Circle().stroke(Color.white.opacity(isShowingLayerPicker ? 0.6 : 0.25), lineWidth: 1))
                            .shadow(color: isShowingLayerPicker ? Theme.Colors.primaryMedium.opacity(0.4) : .black.opacity(0.15), radius: isShowingLayerPicker ? 8 : 5, y: 2)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if isShowingLayerPicker {
                    layerPickerCard
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                }

                summaryCard
                    .id(activeField?.id)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(fieldStore.$activeFieldId) { _ in
            if let newRegion = defaultRegion {
                region = newRegion
            }
        }
        .onAppear {
            if let newRegion = defaultRegion {
                region = newRegion
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(activeField?.name ?? "No active field").textStyle(.bodyStrong)
                Text(fieldStore.fields.isEmpty ? "Register your first field" : "Field \(currentIndex + 1) of \(fieldStore.fields.count)")
                    .textStyle(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18).padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            Spacer()
            avatar
        }
    }

    @ViewBuilder private var avatar: some View {
        UserAvatarView(profileImageURL: profileImageURL, profileInitial: profileInitial, size: 46, onSignOut: onSignOut)
    }

    private var layerPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.3.layers.3d.down.right.fill")
                        .font(.headline)
                        .foregroundColor(Theme.Colors.primaryMedium)
                    Text("Satellite Layers")
                        .font(.headline.weight(.bold))
                        .foregroundColor(Theme.Colors.primary)
                }
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isShowingLayerPicker = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
            
            Text("Switch imagery index for advanced agronomic analysis")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                ForEach(SatelliteLayer.allCases) { layer in
                    let isSelected = selectedLayer == layer
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedLayer = layer
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LinearGradient(colors: layer.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                    .shadow(color: layer.gradientColors.first?.opacity(0.3) ?? .clear, radius: 4, y: 2)
                                Image(systemName: layer.iconName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(layer.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Theme.Colors.primary)
                                    if isSelected {
                                        Text("ACTIVE")
                                            .font(.system(size: 8, weight: .heavy))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Theme.Colors.primaryMedium, in: Capsule())
                                    }
                                }
                                Text(layer.subtitle)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Theme.Colors.primaryMedium)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? Theme.Colors.primaryLight.opacity(0.15) : Color.black.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Theme.Colors.primaryMedium.opacity(0.6) : Color.white.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.92).combined(with: .opacity).combined(with: .move(edge: .bottom)),
            removal: .scale(scale: 0.92).combined(with: .opacity).combined(with: .move(edge: .bottom))
        ))
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: fieldStore.selectPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundColor(Theme.Colors.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(currentIndex == 0)
                .opacity(currentIndex == 0 ? 0.3 : 1.0)
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(activeField?.name ?? "No field selected").font(.title3.bold())
                    Text(coordinateDescription).textStyle(.caption).foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: fieldStore.selectNext) {
                    Image(systemName: "chevron.right")
                        .font(.title3.bold())
                        .foregroundColor(Theme.Colors.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(fieldStore.fields.isEmpty || currentIndex >= fieldStore.fields.count - 1)
                .opacity((fieldStore.fields.isEmpty || currentIndex >= fieldStore.fields.count - 1) ? 0.3 : 1.0)
            }
            
            Divider()
            
            if let field = activeField {
                HStack(alignment: .center, spacing: 16) {
                    if hasLiveSnapshot, let satelliteImageData, let image = UIImage(data: satelliteImageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Colors.primaryMedium.opacity(0.5), lineWidth: 1.5))
                            .shadow(color: healthColor.opacity(0.3), radius: 10, x: 0, y: 4)
                            .overlay(
                                Text("Live NDVI")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .background(Color.black.opacity(0.65), in: Capsule())
                                    .padding(6),
                                alignment: .bottomLeading
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.Colors.primaryLight.opacity(0.1))
                            .frame(width: 100, height: 100)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "leaf.fill").font(.title2).foregroundColor(.secondary)
                                    Text("Pending").font(.caption).foregroundColor(.secondary)
                                }
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        statPill(icon: "ruler", label: "Area", value: field.areaHa.map { String(format: "%.2f ha", $0) } ?? "--")
                        statPill(icon: "leaf", label: "Crop", value: field.cropType ?? "Not set")
                        statPill(icon: "sensor.tag.radiowaves.forward", label: "Sensors", value: hasLiveSnapshot ? "\(sensorCount)" : (isLoadingSnapshot ? "..." : "--"))
                        statPill(icon: "chart.bar.fill", label: "Health", value: field.ndviScore.map { String(format: "%.2f", $0) } ?? "Pending", valueColor: field.ndviScore != nil ? healthColor : Theme.Colors.primary)
                    }
                    Spacer(minLength: 0)
                }
                
                if let message = field.agroError { 
                    Text(message).textStyle(.caption).foregroundStyle(.orange) 
                }
            } else {
                Text("Use the plus button to register a field.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            }
            
            if fieldStore.hasReachedLimit {
                Text("Five fields reached. Delete one before adding another.")
                    .textStyle(.caption).foregroundStyle(.orange)
            }
        }
        .foregroundStyle(Theme.Colors.primary)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statPill(icon: String, label: String, value: String, valueColor: Color = Theme.Colors.primary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).frame(width: 14)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            Spacer(minLength: 4)
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(valueColor).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.black.opacity(0.04), in: Capsule())
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
    
    private var healthColor: Color {
        guard let ndvi = activeField?.ndviScore else { return Theme.Colors.primary }
        switch ndvi {
        case ..<0.3: return .red
        case 0.3..<0.5: return .orange
        case 0.5..<0.7: return .yellow
        default: return .green
        }
    }
    
    private var coordinateDescription: String { center.map { String(format: "%.4f, %.4f", $0.latitude, $0.longitude) } ?? "Coordinates unavailable" }
    
    private var defaultRegion: MKCoordinateRegion? {
        guard let first = boundary.first else { return nil }
        let lats = boundary.map(\.latitude), lons = boundary.map(\.longitude)
        let minLat = lats.min() ?? first.latitude, maxLat = lats.max() ?? first.latitude
        let minLon = lons.min() ?? first.longitude, maxLon = lons.max() ?? first.longitude
        return .init(
            center: .init(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: .init(latitudeDelta: max((maxLat - minLat) * 1.7, 0.002), longitudeDelta: max((maxLon - minLon) * 1.7, 0.002))
        )
    }
    private static let fallbackRegion = MKCoordinateRegion(center: .init(latitude: 31.5204, longitude: 74.3587), span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02))
}

// MARK: - UIKit MKMapView Representable

struct FieldMapView: UIViewRepresentable {
    var boundary: [CLLocationCoordinate2D]
    var centerCoordinate: CLLocationCoordinate2D?
    var fieldTitle: String?
    var satelliteImage: UIImage?
    var tileURL: String?
    var healthColor: UIColor
    @Binding var region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .satelliteFlyover
        mapView.showsCompass = false
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update region ONLY if external region changed and user isn't actively moving
        let currentCenter = uiView.region.center
        let currentSpan = uiView.region.span
        if abs(currentCenter.latitude - region.center.latitude) > 0.001 ||
           abs(currentCenter.longitude - region.center.longitude) > 0.001 ||
           abs(currentSpan.latitudeDelta - region.span.latitudeDelta) > 0.001 {
            uiView.setRegion(region, animated: true)
        }

        // Only rebuild overlays if tileURL, boundary, or healthColor actually changed
        let coordinator = context.coordinator
        let hasTileChanged = coordinator.currentTileURL != tileURL
        let hasBoundaryChanged = coordinator.currentBoundaryCount != boundary.count
        let hasColorChanged = coordinator.currentHealthColor != healthColor

        if hasTileChanged || hasBoundaryChanged || hasColorChanged {
            coordinator.currentTileURL = tileURL
            coordinator.currentBoundaryCount = boundary.count
            coordinator.currentHealthColor = healthColor

            uiView.removeOverlays(uiView.overlays)
            uiView.removeAnnotations(uiView.annotations)

            if !boundary.isEmpty {
                let polygon = MKPolygon(coordinates: boundary, count: boundary.count)
                uiView.addOverlay(polygon)
            }
            
            if let tileUrlString = tileURL {
                let baseString = APIConstants.baseURL.absoluteString
                let normalizedBase = baseString.hasSuffix("/") ? String(baseString.dropLast()) : baseString
                let absoluteTemplate = normalizedBase + (tileUrlString.hasPrefix("/") ? tileUrlString : "/" + tileUrlString)
                let overlay = AuthenticatedTileOverlay(customTemplate: absoluteTemplate)
                overlay.canReplaceMapContent = false
                uiView.addOverlay(overlay, level: .aboveRoads)
            }

            if let center = centerCoordinate {
                let annotation = MKPointAnnotation()
                annotation.coordinate = center
                annotation.title = fieldTitle ?? "Field Center"
                uiView.addAnnotation(annotation)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FieldMapView
        var currentTileURL: String?
        var currentBoundaryCount: Int = -1
        var currentHealthColor: UIColor?

        init(_ parent: FieldMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = parent.healthColor.withAlphaComponent(parent.tileURL == nil ? 0.15 : 0.0)
                renderer.strokeColor = parent.healthColor
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            let identifier = "CenterMarker"
            let marker = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            marker.annotation = annotation
            marker.markerTintColor = parent.healthColor
            marker.glyphImage = UIImage(systemName: "leaf.fill")
            marker.animatesWhenAdded = true
            marker.canShowCallout = true
            return marker
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

class AuthenticatedTileOverlay: MKTileOverlay {
    static let tileCache = NSCache<NSString, NSData>()
    let customTemplate: String
    
    init(customTemplate: String) {
        self.customTemplate = customTemplate
        super.init(urlTemplate: customTemplate)
    }
    
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        var urlStr = customTemplate
        urlStr = urlStr.replacingOccurrences(of: "{z}", with: "\(path.z)")
        urlStr = urlStr.replacingOccurrences(of: "{x}", with: "\(path.x)")
        urlStr = urlStr.replacingOccurrences(of: "{y}", with: "\(path.y)")
        
        urlStr = urlStr.replacingOccurrences(of: "%7Bz%7D", with: "\(path.z)")
        urlStr = urlStr.replacingOccurrences(of: "%7Bx%7D", with: "\(path.x)")
        urlStr = urlStr.replacingOccurrences(of: "%7By%7D", with: "\(path.y)")
        
        return URL(string: urlStr) ?? super.url(forTilePath: path)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let tileUrl = self.url(forTilePath: path)
        let cacheKey = tileUrl.absoluteString as NSString

        // 1. Check in-memory persistent cache first
        if let cachedData = AuthenticatedTileOverlay.tileCache.object(forKey: cacheKey) {
            result(cachedData as Data, nil)
            return
        }

        var request = URLRequest(url: tileUrl)
        request.cachePolicy = .returnCacheDataElseLoad
        
        Auth.auth().currentUser?.getIDTokenForcingRefresh(false) { token, error in
            if let token = token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let data = data, (response as? HTTPURLResponse)?.statusCode == 200 {
                        AuthenticatedTileOverlay.tileCache.setObject(data as NSData, forKey: cacheKey)
                        result(data, nil)
                    } else {
                        result(data, error)
                    }
                }.resume()
            } else {
                result(nil, error ?? NSError(domain: "Auth", code: -1, userInfo: nil))
            }
        }
    }
}
