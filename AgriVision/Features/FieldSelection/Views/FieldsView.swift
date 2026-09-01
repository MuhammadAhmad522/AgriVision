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
    let onSignOut: () -> Void

    @State private var region: MKCoordinateRegion = Self.fallbackRegion

    var body: some View {
        ZStack {
            FieldMapView(
                boundary: boundary,
                centerCoordinate: center,
                satelliteImage: (hasLiveSnapshot && satelliteImageData != nil) ? UIImage(data: satelliteImageData!) : nil,
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
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button(action: onAddField) {
                            Image(systemName: "plus").font(.title2.bold()).foregroundColor(Theme.Colors.primary).frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                        .disabled(fieldStore.hasReachedLimit)
                        
                        Button {
                            if let newRegion = defaultRegion {
                                region = newRegion
                            }
                        } label: {
                            Image(systemName: "location.fill").font(.title2).foregroundColor(Theme.Colors.primary).frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

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
    var satelliteImage: UIImage?
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
        // Update region if changed significantly
        let currentCenter = uiView.region.center
        let currentSpan = uiView.region.span
        if abs(currentCenter.latitude - region.center.latitude) > 0.0001 ||
           abs(currentCenter.longitude - region.center.longitude) > 0.0001 ||
           abs(currentSpan.latitudeDelta - region.span.latitudeDelta) > 0.0001 {
            uiView.setRegion(region, animated: true)
        }

        uiView.removeOverlays(uiView.overlays)
        uiView.removeAnnotations(uiView.annotations)

        if !boundary.isEmpty {
            let polygon = MKPolygon(coordinates: boundary, count: boundary.count)
            uiView.addOverlay(polygon)
        }

        if let center = centerCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = center
            annotation.title = "Field Center"
            uiView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FieldMapView

        init(_ parent: FieldMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = ImagePolygonRenderer(polygon: polygon)
                renderer.image = parent.satelliteImage
                renderer.fillColor = parent.healthColor.withAlphaComponent(0.35)
                renderer.strokeColor = parent.healthColor
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "CenterAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = false
                
                // Create a pulsing radar view
                let circleView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
                circleView.backgroundColor = parent.healthColor
                circleView.layer.cornerRadius = 8
                circleView.layer.borderColor = UIColor.white.cgColor
                circleView.layer.borderWidth = 2.5
                circleView.layer.shadowColor = UIColor.black.cgColor
                circleView.layer.shadowOpacity = 0.3
                circleView.layer.shadowOffset = CGSize(width: 0, height: 2)
                circleView.layer.shadowRadius = 3
                
                let pulseView = UIView(frame: CGRect(x: -16, y: -16, width: 48, height: 48))
                pulseView.backgroundColor = parent.healthColor.withAlphaComponent(0.4)
                pulseView.layer.cornerRadius = 24
                circleView.addSubview(pulseView)
                
                let animation = CABasicAnimation(keyPath: "transform.scale")
                animation.fromValue = 0.6
                animation.toValue = 1.4
                animation.duration = 1.5
                animation.repeatCount = .infinity
                
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 1.0
                fade.toValue = 0.0
                fade.duration = 1.5
                fade.repeatCount = .infinity
                
                pulseView.layer.add(animation, forKey: "pulse")
                pulseView.layer.add(fade, forKey: "fade")
                
                view?.addSubview(circleView)
                view?.frame = circleView.frame
            } else {
                view?.annotation = annotation
            }
            return view
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

class ImagePolygonRenderer: MKPolygonRenderer {
    var image: UIImage?
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        if let image = image, let cgImage = image.cgImage {
            // Clip to polygon bounds
            context.addPath(self.path)
            context.clip()
            
            // Draw image filling the polygon bounding rect
            let rect = self.rect(for: self.polygon.boundingMapRect)
            context.translateBy(x: 0, y: rect.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(cgImage, in: CGRect(x: rect.minX, y: -rect.minY, width: rect.width, height: rect.height))
            
            // Draw border
            context.resetClip()
            context.addPath(self.path)
            context.setStrokeColor(self.strokeColor?.cgColor ?? UIColor.green.cgColor)
            context.setLineWidth(self.lineWidth / zoomScale)
            context.strokePath()
        } else {
            super.draw(mapRect, zoomScale: zoomScale, in: context)
        }
    }
}
