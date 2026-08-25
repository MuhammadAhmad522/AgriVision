import SwiftUI
import MapKit

struct FieldSelectionView: View {
    @ObservedObject var viewModel: FieldSelectionViewModel
    @Namespace private var animation
    @State private var areToolsExpanded = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // 1. Real MapKit View
                RepresentableMap(
                    region: $viewModel.region,
                    fieldCoordinates: viewModel.fieldCoordinates,
                    onTap: { coordinate in
                        viewModel.addPoint(coordinate)
                    },
                    onUpdatePoint: { index, coordinate in
                        viewModel.movePoint(at: index, to: coordinate)
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // 2. UI Overlays
                // Single overlay structure to minimize hit-testing issues
                VStack(spacing: 0) {
                    // Top Bar
                    ZStack(alignment: .top) {
                        if viewModel.isSearching {
                            // Expanded Search View
                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(Theme.Colors.primary)
                                        .textStyle(.body)
                                    
                                    TextField("Search location...", text: $viewModel.searchQuery)
                                        .textStyle(.body)
                                        .foregroundColor(Theme.Colors.primary)
                                        .accentColor(Theme.Colors.primaryMedium)
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            viewModel.isSearching = false
                                            viewModel.searchQuery = ""
                                            viewModel.searchResults = []
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Theme.Colors.primary.opacity(0.6))
                                            .textStyle(.body)
                                    }
                                }
                                .padding(10)
                                .background(
                                    ZStack {
                                        VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                                        Color.white.opacity(0.3)
                                    }
                                    .cornerRadius(20)
                                    .matchedGeometryEffect(id: "searchBackground", in: animation)
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                                )
                                
                                if !viewModel.searchResults.isEmpty {
                                    ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 0) {
                                            ForEach(viewModel.searchResults, id: \.self) { result in
                                                Button(action: {
                                                    withAnimation {
                                                        viewModel.selectSearchResult(result)
                                                    }
                                                }) {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(result.title)
                                                            .textStyle(.captionStrong)
                                                            .foregroundColor(Theme.Colors.primary)
                                                        
                                                        Text(result.subtitle)
                                                            .textStyle(.caption)
                                                            .foregroundColor(Theme.Colors.primary.opacity(0.8))
                                                    }
                                                    .padding(.vertical, 10)
                                                    .padding(.horizontal, 16)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .contentShape(Rectangle())
                                                }
                                                
                                                Divider()
                                                    .background(Theme.Colors.primary.opacity(0.1))
                                            }
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .frame(maxHeight: 250)
                                    .background(
                                        ZStack {
                                            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                                            Color.white.opacity(0.8)
                                        }
                                        .cornerRadius(16)
                                    )
                                    .padding(.top, 8)
                                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                                    .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 60)
                            .zIndex(2) // Ensure it sits on top
                        } else {
                            // Standard Top Bar
                            HStack(spacing: 12) {
                                // Location Pill - Now Interactive
                                Button(action: {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        viewModel.isSearching = true
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "location.fill")
                                            .resizable()
                                            .frame(width: 12, height: 12)
                                            .padding(5)
                                            .background(Theme.Colors.primary)
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                        
                                        Text(viewModel.locationName)
                                            .textStyle(.captionStrong)
                                            .foregroundColor(Theme.Colors.primary)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        ZStack {
                                            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                                            Color.white.opacity(0.3)
                                        }
                                        .cornerRadius(100)
                                        .matchedGeometryEffect(id: "searchBackground", in: animation)
                                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    )
                                }
                                
                                Spacer()
                                
                                // Profile Avatar
                                UserAvatarView(
                                    profileImageURL: viewModel.profileImageURL,
                                    profileInitial: viewModel.profileInitial,
                                    size: 36,
                                    onSignOut: viewModel.signOut
                                )
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, 60)
                            .zIndex(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Interaction Elements (Toolbar, FABs)
                    HStack(alignment: .bottom) {
                        // Left Collapsible Toolbar
                        VStack(spacing: 12) {
                            if areToolsExpanded {
                                ToolButton(icon: "arrow.uturn.backward", action: { viewModel.undoLastPoint() })
                                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.5, anchor: .bottom)))
                                
                                ToolButton(icon: "minus.magnifyingglass", action: { viewModel.zoomOut() })
                                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.5, anchor: .bottom)))
                                
                                ToolButton(icon: "plus.magnifyingglass", action: { viewModel.zoomIn() })
                                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.5, anchor: .bottom)))
                                
                                ToolButton(icon: "eraser.line.dashed", action: { viewModel.clearPoints() })
                                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.5, anchor: .bottom)))
                            }
                            
                            // Toggle Button
                            ToolButton(
                                icon: areToolsExpanded ? "xmark" : "pencil.and.outline",
                                action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        areToolsExpanded.toggle()
                                    }
                                },
                                isActive: areToolsExpanded,
                                isMainToggle: true
                            )
                        }
                        .padding(.bottom, 20)
                        
                        Spacer()
                        
                        // "Near Me" / Location Button
                        Button(action: {
                            viewModel.centerOnUserLocation()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Theme.Colors.primaryLight, Theme.Colors.primaryMedium],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    .frame(width: 50, height: 50)
                                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 4)
                                
                                Image(systemName: "location.north.circle.fill")
                                    .textStyle(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                    
                    // Bottom Card
                    VStack(spacing: 0) {
                        Spacer().frame(height: 24)
                        
                        Text("Draw Your Field Boundry")
                            .textStyle(.bodyStrong) // Reduced size
                            .foregroundColor(Theme.Colors.primary)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        Spacer().frame(height: 16)
                        
                        // Confirm Button
                        Button(action: { viewModel.confirmField() }) {
                            Text("Confirm Field")
                                .textStyle(.bodyStrong) // Reduced size
                                .foregroundColor(Theme.Colors.background)
                                .frame(width: 300, height: 50) // Reduced size
                                .background(
                                    LinearGradient(
                                        colors: [Theme.Colors.primaryLight, Theme.Colors.primaryMedium],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(25)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                        
                        Spacer().frame(height: 16)
                        
                        Text("Tap on the map to add points")
                            .textStyle(.captionStrong) // Reduced size
                            .foregroundColor(Theme.Colors.primary.opacity(0.8))
                        
                        Spacer()
                    }
                    .frame(height: 200) // Reduced height
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                            Color.white.opacity(0.4)
                        }
                    )
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
                    .padding(.bottom, -30) // Overlap bottom edge
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .allowsHitTesting(true) // Ensure buttons are clickable
            }
        }
        .ignoresSafeArea() // Use modern API for safe area
        .ignoresSafeArea(.keyboard) // Explicitly ignore keyboard adjustment for the whole view
        .overlay(alignment: .top) {
            Group {
                if let error = viewModel.errorMessage {
                    ToastView(message: error, type: .error)
                } else if let success = viewModel.successMessage {
                    ToastView(message: success, type: .success)
                }
            }
            .padding(.top, 60) // Position below top bar or status bar area approx
            .padding(.horizontal, 16)
            .animation(.spring(), value: viewModel.errorMessage)
            .animation(.spring(), value: viewModel.successMessage)
        }
    }
}

// MARK: - UIViewRepresentable Map
struct RepresentableMap: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var fieldCoordinates: [CLLocationCoordinate2D]
    var onTap: (CLLocationCoordinate2D) -> Void
    var onUpdatePoint: (Int, CLLocationCoordinate2D) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .hybrid // Changed to hybrid for better field visibility
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true // Ensure pitch is enabled
        mapView.showsCompass = false // Hide default compass so we can add a custom one that doesn't overlap
        
        // Handle taps for adding points
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false // Crucial: Allow other gestures (like Pinch/Pan) to pass through
        mapView.addGestureRecognizer(tapGesture)
        
        // Add Custom Compass
        let compassButton = MKCompassButton(mapView: mapView)
        compassButton.compassVisibility = .adaptive
        compassButton.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(compassButton)
        
        // Position compass below the profile icon (top-right)
        NSLayoutConstraint.activate([
            compassButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -12),
            compassButton.topAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.topAnchor, constant: 100)
        ])
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update coordinator's parent to access latest bindings
        context.coordinator.parent = self
        
        // If the map is currently being interacted with (panning/zooming),
        // we should NOT force a region update from SwiftUI, as it causes stuttering/fighting.
        if context.coordinator.isMapMoving {
            return
        }
        
        // Check if the current map region is significantly different from the binding.
        // We use a threshold to prevent minor floating point jitter from triggering updates.
        // Importantly, during a pinch/pan, the coordinator updates the binding continuously.
        // So 'region' should remain close to 'uiView.region'.
        // If 'region' is close enough, we skip setRegion to avoid interrupting the gesture.
        
        // Calculate difference
        let currentRegion = uiView.region
        let centerDiff = abs(currentRegion.center.latitude - region.center.latitude) + abs(currentRegion.center.longitude - region.center.longitude)
        let spanDiff = abs(currentRegion.span.latitudeDelta - region.span.latitudeDelta) + abs(currentRegion.span.longitudeDelta - region.span.longitudeDelta)
        
        let isProgrammaticUpdate = centerDiff > 0.0005 || spanDiff > 0.0005
        
        if isProgrammaticUpdate {
            uiView.setRegion(region, animated: true)
        }
        
        // Refresh overlays/annotations only if data changed
        if !context.coordinator.areCoordinatesEqual(fieldCoordinates) {
            uiView.removeOverlays(uiView.overlays)
            uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })
            
            for (index, coord) in fieldCoordinates.enumerated() {
                let annotation = IndexedPointAnnotation()
                annotation.coordinate = coord
                annotation.title = "Point \(index + 1)"
                annotation.index = index
                uiView.addAnnotation(annotation)
            }
            
            if fieldCoordinates.count >= 3 {
                let polygon = MKPolygon(coordinates: fieldCoordinates, count: fieldCoordinates.count)
                uiView.addOverlay(polygon)
            } else if fieldCoordinates.count == 2 {
                let polyline = MKPolyline(coordinates: fieldCoordinates, count: fieldCoordinates.count)
                uiView.addOverlay(polyline)
            }
            
            context.coordinator.lastFieldCoordinates = fieldCoordinates
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Custom Annotation to store index
    class IndexedPointAnnotation: MKPointAnnotation {
        var index: Int = 0
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RepresentableMap
        var lastFieldCoordinates: [CLLocationCoordinate2D] = []
        var lastRegion: MKCoordinateRegion = MKCoordinateRegion()
        var isMapMoving = false // Track if map is changing
        
        init(_ parent: RepresentableMap) {
            self.parent = parent
            self.lastRegion = parent.region
        }
        
        func areCoordinatesEqual(_ newCoordinates: [CLLocationCoordinate2D]) -> Bool {
            if lastFieldCoordinates.count != newCoordinates.count { return false }
            for (index, coord) in newCoordinates.enumerated() {
                if coord.latitude != lastFieldCoordinates[index].latitude ||
                   coord.longitude != lastFieldCoordinates[index].longitude {
                    return false
                }
            }
            return true
        }
        
        // MARK: - MapView Delegate
        
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Mark map as moving to prevent SwiftUI loop
            isMapMoving = true
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Final sync at the end of animation/gesture
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.region = mapView.region
                self.isMapMoving = false // Reset flag
            }
        }
        
        // Critical for Pinch-to-Zoom:
        // Update binding continuously during the gesture so SwiftUI state doesn't get stale.
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            // Ensure flag is true during continuous updates
            isMapMoving = true
            
            // Throttle/Debounce binding updates slightly if needed, but usually direct dispatch is fine.
            // Using a plain async here keeps the binding fresh.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.parent.region = mapView.region
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Only process if it's a discrete tap, not part of a drag/pinch
            guard gesture.state == .ended else { return }
            
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            
            // Avoid adding point if tapping on an existing annotation (handled by didSelect/drag)
            // But tap gesture might steal it. For now simple tap adds points.
            // If dragging is enabled, we need to ensure we don't add a point when grabbing one.
            
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTap(coordinate)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor(Theme.Colors.warning).withAlphaComponent(0.2)
                renderer.strokeColor = UIColor(Theme.Colors.warning)
                renderer.lineWidth = 3
                renderer.lineDashPattern = [10, 5]
                return renderer
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Theme.Colors.warning)
                renderer.lineWidth = 3
                renderer.lineDashPattern = [10, 5]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            let identifier = "DraggablePoint"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.image = UIImage(systemName: "circle.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
                view?.backgroundColor = .clear
                view?.isDraggable = true // Enable dragging
                
                let dot = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
                dot.backgroundColor = .white
                dot.layer.cornerRadius = 5
                
                // Increase hit target
                view?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                dot.center = CGPoint(x: 15, y: 15)
                
                view?.addSubview(dot)
            } else {
                view?.annotation = annotation
            }
            return view
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending || newState == .none {
                if let indexedAnnotation = view.annotation as? IndexedPointAnnotation {
                    // Update model
                    parent.onUpdatePoint(indexedAnnotation.index, indexedAnnotation.coordinate)
                }
            }
        }
    }
}

// Helper Views
struct ToolButton: View {
    let icon: String
    var action: () -> Void
    var isActive: Bool = false
    var isMainToggle: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isMainToggle {
                    // Main Toggle Button Style (Matches Location Button)
                    Circle()
                        .fill(LinearGradient(
                            colors: [Theme.Colors.primaryLight, Theme.Colors.primaryMedium],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 50, height: 50)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 4)
                    
                    Image(systemName: icon)
                        .textStyle(.title2)
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isActive ? 90 : 0))
                } else {
                    // Standard Tool Button Style (Liquid Glass)
                    ZStack {
                        VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                            .opacity(0.9)
                        
                        Color.white.opacity(0.6)
                            .blendMode(.overlay)
                        
                        Theme.Colors.background.opacity(0.3) // Tint to match theme
                    }
                    .clipShape(Circle())
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    
                    Image(systemName: icon)
                        .textStyle(.bodyStrong)
                        .foregroundColor(Theme.Colors.primaryMedium)
                }
            }
            .frame(width: 50, height: 50)
            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
        }
    }
}

// Needs Core/UI/VisualEffectBlur now

// MARK: - Previews
#Preview {
    let authService = MockAuthService(isLoggedIn: true)
    let dataService = MockAgriDataRepository()
    let viewModel = FieldSelectionViewModel(authService: authService, dataService: dataService)
    
    FieldSelectionView(viewModel: viewModel)
}
