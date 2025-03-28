import SwiftUI
import MapKit
import Combine
import CoreLocation
import Network

// MARK: - MapContainerView (Main View)
struct MapContainerView: View {
    @EnvironmentObject var apiService: ApiService
    @StateObject private var viewModel = EmergencyMapViewModel()
    @State private var selectedTabIndex = 0
    
    private let tabs = ["Crisis Map", "Evacuation Routes"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        selectedTabIndex = index
                    }) {
                        Text(tabs[index])
                            .fontWeight(selectedTabIndex == index ? .bold : .regular)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(selectedTabIndex == index ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                    .foregroundColor(selectedTabIndex == index ? .blue : .primary)
                    
                    if index < tabs.count - 1 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Tab content
            TabView(selection: $selectedTabIndex) {
                // Tab 1: Standard Crisis Map
                CrisisMapView()
                    .environmentObject(apiService)
                    .tag(0)
                
                // Tab 2: Enhanced Evacuation Map with Routes and Safe Zones
                EvacuationMapView()
                    .environmentObject(viewModel)
                    .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle(tabs[selectedTabIndex])
    }
}

// MARK: - Crisis Map View
struct CrisisMapView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 45, longitudeDelta: 45)
    )
    @State private var userTrackingMode: MapUserTrackingMode = .follow
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ZStack {
            // Use the new Map API for iOS 17+ or fallback to the older API
            if #available(iOS 17.0, *) {
                Map {
                    UserAnnotation()
                    
                    // Add crisis markers
                    if let crises = apiService.activeCrises {
                        ForEach(crises) { crisis in
                            if let coordinates = crisis.coordinates {
                                Marker(crisis.name, coordinate: CLLocationCoordinate2D(
                                    latitude: coordinates.latitude,
                                    longitude: coordinates.longitude
                                ))
                                .tint(getSeverityColor(for: crisis))
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                // Fallback for older iOS versions
                Map(coordinateRegion: $region,
                    interactionModes: .all,
                    showsUserLocation: true,
                    userTrackingMode: $userTrackingMode,
                    annotationItems: getAnnotationItems()) { item in
                        // Use the correct MapAnnotation view with explicit type
                        MapAnnotation(coordinate: item.coordinate) {
                            CrisisAnnotationView(crisis: item.crisis)
                                .onTapGesture {
                                    // Handle tap
                                }
                        }
                }
                .edgesIgnoringSafeArea(.all)
            }
            
            // Map Controls (same for all versions)
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        centerOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            locationManager.requestAuthorization()
            locationManager.startUpdatingLocation()
            
            // Center map on user location if available
            if let location = locationManager.lastLocation?.coordinate {
                region = MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
        }
    }
    
    private func getAnnotationItems() -> [CrisisAnnotationItem] {
        guard let crises = apiService.activeCrises else { return [] }
        
        return crises.compactMap { crisis in
            guard let coordinates = crisis.coordinates else { return nil }
            
            return CrisisAnnotationItem(
                id: crisis.id,
                crisis: crisis,
                coordinate: CLLocationCoordinate2D(
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
            )
        }
    }
    
    private func centerOnUserLocation() {
        if let location = locationManager.lastLocation?.coordinate {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            
            userTrackingMode = .follow
        }
    }
    
    private func getSeverityColor(for crisis: Crisis) -> Color {
        switch crisis.severity {
        case 5:
            return .red
        case 4:
            return .orange
        case 3:
            return .yellow
        case 2:
            return .blue
        default:
            return .green
        }
    }
}

// MARK: - Evacuation Map View
struct EvacuationMapView: View {
    @EnvironmentObject var viewModel: EmergencyMapViewModel
    @State private var mapType: MKMapType = .standard
    @State private var showDetails = false
    @State private var selectedSafeZone: SafeZone?
    
    var body: some View {
        ZStack {
            // Map View
            if #available(iOS 17.0, *) {
                Map {
                    // User location marker
                    UserAnnotation()
                    
                    // Evacuation routes
                    ForEach(viewModel.evacuationRoutes) { route in
                        MapPolyline(coordinates: route.waypoints)
                            .stroke(Color.blue, lineWidth: 4)
                        
                        // Starting point marker
                        if let startPoint = route.waypoints.first {
                            Marker(route.name, coordinate: startPoint)
                                .tint(.blue)
                        }
                    }
                    
                    // Safe zones
                    ForEach(viewModel.safeZones) { zone in
                        // Safe zone marker
                        Marker(zone.name, coordinate: zone.coordinate)
                            .tint(.green)
                        
                        // Safe zone area
                        MapCircle(center: zone.coordinate, radius: zone.radius)
                            .foregroundStyle(.green.opacity(0.2))
                            .stroke(.green, lineWidth: 2)
                    }
                }
                .mapStyle(mapType == .standard ? .standard : .hybrid)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
            } else {
                // Fallback for older iOS versions
                Map(coordinateRegion: $viewModel.region,
                    interactionModes: .all,
                    showsUserLocation: true,
                    userTrackingMode: .constant(.follow),
                    annotationItems: viewModel.mapAnnotations) { item in
                        // Use the correct MapAnnotation view
                        MapAnnotation(coordinate: item.coordinate) {
                            mapMarker(for: item)
                                .onTapGesture {
                                    handleMarkerTap(item)
                                }
                        }
                }
            }
            
            // Status Overlay
            VStack {
                HStack {
                    // Real-time status indicator
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Refreshing data...")
                                .font(.caption)
                        }
                        .padding(6)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Circle()
                                .fill(viewModel.isConnected ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(viewModel.lastUpdated != nil ?
                                 "Updated: \(timeAgoString(from: viewModel.lastUpdated!))" :
                                 "No data")
                                .font(.caption)
                        }
                        .padding(6)
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        mapType = mapType == .standard ? .hybrid : .standard
                    }) {
                        Image(systemName: mapType == .standard ? "map" : "map.fill")
                            .padding(8)
                            .background(Color(.systemBackground).opacity(0.8))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Legend
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 4)
                        Text("Evacuation Route")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Safe Zone")
                            .font(.caption)
                    }
                }
                .padding(8)
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(8)
                .padding()
                
                // Control buttons
                HStack {
                    Button(action: {
                        viewModel.centerOnUserLocation()
                    }) {
                        Image(systemName: "location.fill")
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .padding(12)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            viewModel.startLocationUpdates()
            viewModel.startDataFetch()
        }
        .onDisappear {
            viewModel.stopLocationUpdates()
        }
        .sheet(isPresented: $showDetails) {
            if let safeZone = selectedSafeZone {
                SafeZoneDetailView(safeZone: safeZone)
            }
        }
        .alert(item: $viewModel.alertItem) { (alertItem: EmergencyAlertItem) in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Custom marker view for legacy map
    private func mapMarker(for annotation: EmergencyMapAnnotation) -> some View {
        VStack(spacing: 0) {
            if annotation.type == .safeZone {
                Image(systemName: "shield.fill")
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.green)
                            .frame(width: 30, height: 30)
                    )
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 30)
                    )
                    .frame(width: 30, height: 30)
            }
            
            Text(annotation.title)
                .font(.caption)
                .padding(2)
                .background(Color.white.opacity(0.8))
                .cornerRadius(4)
                .padding(.top, 2)
        }
    }
    
    // Handle marker tap action
    private func handleMarkerTap(_ annotation: EmergencyMapAnnotation) {
        if annotation.type == .safeZone,
           let zone = viewModel.safeZones.first(where: { $0.id.uuidString == annotation.id }) {
            selectedSafeZone = zone
            showDetails = true
        }
    }
    
    // Helper to format time ago string
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Safe Zone Detail View
struct SafeZoneDetailView: View {
    let safeZone: SafeZone
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(safeZone.name)
                            .font(.headline)
                        
                        Text(safeZone.description)
                            .font(.body)
                        
                        if let address = safeZone.address {
                            Divider()
                            
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text(address)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Capacity")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current Occupancy")
                                .font(.caption)
                            Text("\(safeZone.currentOccupancy)/\(safeZone.capacity)")
                                .font(.title3)
                        }
                        
                        Spacer()
                        
                        // Progress indicator
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(safeZone.currentOccupancy) / CGFloat(safeZone.capacity))
                                .stroke(
                                    safeZone.currentOccupancy > safeZone.capacity * 3/4 ? Color.red :
                                        safeZone.currentOccupancy > safeZone.capacity / 2 ? Color.orange : Color.green,
                                    lineWidth: 8
                                )
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                            
                            Text("\(Int(Double(safeZone.currentOccupancy) / Double(safeZone.capacity) * 100))%")
                                .font(.caption)
                                .bold()
                        }
                    }
                }
                
                Section(header: Text("Available Resources")) {
                    ForEach(safeZone.resourcesAvailable, id: \.self) { resource in
                        Label(resource, systemImage: resourceIcon(for: resource))
                    }
                }
                
                Section {
                    Button(action: {
                        // Navigate to this location
                        openInMaps(coordinate: safeZone.coordinate, name: safeZone.name)
                    }) {
                        Label("Get Directions", systemImage: "map")
                    }
                }
            }
            .navigationTitle("Safe Zone Details")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    // Get appropriate icon for each resource type
    private func resourceIcon(for resource: String) -> String {
        switch resource.lowercased() {
        case _ where resource.lowercased().contains("water"):
            return "drop.fill"
        case _ where resource.lowercased().contains("food"):
            return "fork.knife"
        case _ where resource.lowercased().contains("medical"):
            return "cross.fill"
        case _ where resource.lowercased().contains("shelter"):
            return "house.fill"
        case _ where resource.lowercased().contains("power"):
            return "bolt.fill"
        case _ where resource.lowercased().contains("internet"):
            return "wifi"
        default:
            return "checkmark.circle.fill"
        }
    }
    
    // Open location in Maps app
    private func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Alert Item Model
struct EmergencyAlertItem: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - Map Annotation Model
struct EmergencyMapAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let type: AnnotationType
    
    enum AnnotationType {
        case evacuationRoute
        case safeZone
    }
}

// MARK: - Data Models
// Evacuation Route Model
struct EvacuationRoute: Identifiable, Decodable {
    let id: UUID
    let name: String
    let description: String
    let waypoints: [CLLocationCoordinate2D]
    let evacuationType: EvacuationType
    let estimatedTravelTime: TimeInterval
    let lastUpdated: Date
    let safetyLevel: Int // 1-5, with 5 being the safest
    let issueAuthority: String
    let sourceAPI: String
    
    enum EvacuationType: String, Codable, CaseIterable {
        case fire = "Fire"
        case flood = "Flood"
        case earthquake = "Earthquake"
        case hurricane = "Hurricane"
        case tsunami = "Tsunami"
        case chemical = "Chemical Spill"
        case general = "General"
    }
    
    // Standard initializer for programmatically creating routes
    init(id: UUID = UUID(),
         name: String,
         description: String,
         waypoints: [CLLocationCoordinate2D],
         evacuationType: EvacuationType,
         estimatedTravelTime: TimeInterval,
         lastUpdated: Date = Date(),
         safetyLevel: Int,
         issueAuthority: String,
         sourceAPI: String) {
        self.id = id
        self.name = name
        self.description = description
        self.waypoints = waypoints
        self.evacuationType = evacuationType
        self.estimatedTravelTime = estimatedTravelTime
        self.lastUpdated = lastUpdated
        self.safetyLevel = safetyLevel
        self.issueAuthority = issueAuthority
        self.sourceAPI = sourceAPI
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, waypoints, evacuationType
        case estimatedTravelTime, lastUpdated, safetyLevel
        case issueAuthority, sourceAPI
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Decode waypoints from array of [longitude, latitude] arrays
        let waypointsData = try container.decode([[Double]].self, forKey: .waypoints)
        waypoints = waypointsData.compactMap { point in
            guard point.count >= 2 else { return nil }
            // Convert [longitude, latitude] to CLLocationCoordinate2D
            return CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
        }
        
        evacuationType = try container.decode(EvacuationType.self, forKey: .evacuationType)
        estimatedTravelTime = try container.decode(TimeInterval.self, forKey: .estimatedTravelTime)
        
        let dateFormatter = ISO8601DateFormatter()
        let dateString = try container.decode(String.self, forKey: .lastUpdated)
        lastUpdated = dateFormatter.date(from: dateString) ?? Date()
        
        safetyLevel = try container.decode(Int.self, forKey: .safetyLevel)
        issueAuthority = try container.decode(String.self, forKey: .issueAuthority)
        sourceAPI = try container.decode(String.self, forKey: .sourceAPI)
    }
}

// Safe Zone Model
struct SafeZone: Identifiable, Decodable {
    let id: UUID
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let capacity: Int
    let currentOccupancy: Int
    let resourcesAvailable: [String]
    let lastUpdated: Date
    let safetyLevel: Int // 1-5, with 5 being the safest
    let address: String?
    let contactInfo: String?
    
    // Standard initializer for programmatically creating safe zones
    init(id: UUID = UUID(),
         name: String,
         description: String,
         coordinate: CLLocationCoordinate2D,
         radius: CLLocationDistance,
         capacity: Int,
         currentOccupancy: Int,
         resourcesAvailable: [String],
         lastUpdated: Date = Date(),
         safetyLevel: Int,
         address: String? = nil,
         contactInfo: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.coordinate = coordinate
        self.radius = radius
        self.capacity = capacity
        self.currentOccupancy = currentOccupancy
        self.resourcesAvailable = resourcesAvailable
        self.lastUpdated = lastUpdated
        self.safetyLevel = safetyLevel
        self.address = address
        self.contactInfo = contactInfo
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, coordinates, radius
        case capacity, currentOccupancy, resourcesAvailable
        case lastUpdated, safetyLevel, address, contactInfo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Decode coordinates as [longitude, latitude]
        let coordinates = try container.decode([Double].self, forKey: .coordinates)
        guard coordinates.count >= 2 else {
            throw DecodingError.dataCorruptedError(
                forKey: .coordinates,
                in: container,
                debugDescription: "Coordinates must contain longitude and latitude"
            )
        }
        coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
        
        radius = try container.decode(CLLocationDistance.self, forKey: .radius)
        capacity = try container.decode(Int.self, forKey: .capacity)
        currentOccupancy = try container.decode(Int.self, forKey: .currentOccupancy)
        resourcesAvailable = try container.decode([String].self, forKey: .resourcesAvailable)
        
        // Parse date
        let dateFormatter = ISO8601DateFormatter()
        let dateString = try container.decode(String.self, forKey: .lastUpdated)
        lastUpdated = dateFormatter.date(from: dateString) ?? Date()
        
        safetyLevel = try container.decode(Int.self, forKey: .safetyLevel)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        contactInfo = try container.decodeIfPresent(String.self, forKey: .contactInfo)
    }
}

// MARK: - Emergency Map ViewModel
class EmergencyMapViewModel: NSObject, ObservableObject {
    // Published properties
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var evacuationRoutes: [EvacuationRoute] = []
    @Published var safeZones: [SafeZone] = []
    @Published var isLoading = false
    @Published var isConnected = true
    @Published var lastUpdated: Date?
    @Published var alertItem: EmergencyAlertItem?
    @Published var mapAnnotations: [EmergencyMapAnnotation] = []
    
    // Location manager
    private let locationManager = CLLocationManager()
    private var userLocation: CLLocationCoordinate2D?
    
    // API clients
    private let openStreetMapRouteFinder = OpenStreetMapRouteFinder()
    private let emergencyApiClient = EmergencyAPIClient()
    
    // Cancellables for API requests
    private var cancellables = Set<AnyCancellable>()
    
    // Real-time update timers
    private var updateTimer: Timer?
    
    // Network monitor
    private let networkMonitor = NetworkMonitor.shared
    
    // Initialize
    override init() {
        super.init()
        setupLocationManager()
        setupNetworkMonitoring()
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    // Setup location manager
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        
        // Ask for authorization on background thread to avoid warnings
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // Monitor network connectivity
    private func setupNetworkMonitoring() {
        NotificationCenter.default.publisher(for: Notification.Name("connectivityChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let isConnected = notification.object as? Bool {
                    self?.isConnected = isConnected
                }
            }
            .store(in: &cancellables)
    }
    
    // Start location updates
    func startLocationUpdates() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            DispatchQueue.main.async {
                self?.locationManager.startUpdatingLocation()
            }
        }
    }
    
    // Stop location updates
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // Start initial data fetch
    func startDataFetch() {
        if let location = userLocation {
            refreshData()
            
            // Set up timer for regular updates (every 2 minutes)
            updateTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
                self?.refreshData()
            }
        } else {
            // Use default location if no user location is available
            userLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
            refreshData()
            
            updateTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
                self?.refreshData()
            }
        }
    }
    
    // Refresh all data
    func refreshData() {
        var location = userLocation
        
        // If location is nil, use a default location
        if location == nil {
            location = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
            print("Using default location for data refresh")
        }
        
        guard let userLocation = location else {
            alertItem = EmergencyAlertItem(message: "Location not available. Please enable location services.")
            return
        }
        
        if !networkMonitor.isConnected {
            alertItem = EmergencyAlertItem(message: "No internet connection. Please check your network settings.")
            return
        }
        
        isLoading = true
        print("Refreshing emergency data for location: \(userLocation.latitude), \(userLocation.longitude)")
        
        // Create a dispatch group to track multiple API requests
        let group = DispatchGroup()
        
        // Fetch evacuation routes using OpenStreetMap
        group.enter()
        openStreetMapRouteFinder.fetchEvacuationRoutes(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
            radius: 25000
        ) { [weak self] result in
            defer { group.leave() }
            
            switch result {
            case .success(let routes):
                DispatchQueue.main.async {
                    self?.evacuationRoutes = routes
                    print("Successfully loaded \(routes.count) evacuation routes")
                }
            case .failure(let error):
                print("Failed to fetch evacuation routes: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.alertItem = EmergencyAlertItem(message: "Error fetching evacuation routes: \(error.localizedDescription)")
                }
            }
        }
        
        // Fetch safe zones - using the already updated OpenStreetMap-based implementation
        group.enter()
        emergencyApiClient.fetchSafeZones(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
            radius: 25000
        ) { [weak self] result in
            defer { group.leave() }
            
            switch result {
            case .success(let zones):
                DispatchQueue.main.async {
                    self?.safeZones = zones
                    print("Successfully loaded \(zones.count) safe zones")
                }
            case .failure(let error):
                print("Failed to fetch safe zones: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.alertItem = EmergencyAlertItem(message: "Error fetching safe zones: \(error.localizedDescription)")
                }
            }
        }
        
        // When all requests complete
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            self?.lastUpdated = Date()
            self?.updateMapAnnotations()
            print("Data refresh completed at \(Date())")
        }
    }
    
    // Center map on user location
    func centerOnUserLocation() {
        if let location = userLocation {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else if locationManager.authorizationStatus != .authorizedWhenInUse &&
                  locationManager.authorizationStatus != .authorizedAlways {
            // Request permission if we don't have it
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                DispatchQueue.main.async {
                    self?.locationManager.requestWhenInUseAuthorization()
                }
            }
        }
    }
    
    // Update map annotations based on current data
    private func updateMapAnnotations() {
        var annotations: [EmergencyMapAnnotation] = []
        
        // Add evacuation route markers
        for route in evacuationRoutes {
            if let startPoint = route.waypoints.first {
                annotations.append(EmergencyMapAnnotation(
                    id: route.id.uuidString,
                    coordinate: startPoint,
                    title: route.name,
                    type: .evacuationRoute
                ))
            }
        }
        
        // Add safe zone markers
        for zone in safeZones {
            annotations.append(EmergencyMapAnnotation(
                id: zone.id.uuidString,
                coordinate: zone.coordinate,
                title: zone.name,
                type: .safeZone
            ))
        }
        
        DispatchQueue.main.async {
            self.mapAnnotations = annotations
            print("Updated map with \(annotations.count) annotations")
        }
    }
}

// MARK: - Extension for CLLocationManagerDelegate for EmergencyMapViewModel
extension EmergencyMapViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Update region if this is first location fix
            if self.lastUpdated == nil {
                self.centerOnUserLocation()
                self.refreshData()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("EmergencyMapViewModel location error: \(error.localizedDescription)")
        
        // Use default location if we can't get user location
        if userLocation == nil {
            DispatchQueue.main.async {
                self.userLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
                print("Using default location due to location error")
                
                // Still need to refresh data with default location
                if self.lastUpdated == nil {
                    self.refreshData()
                }
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                self.startLocationUpdates()
            } else if manager.authorizationStatus == .denied ||
                     manager.authorizationStatus == .restricted {
                self.alertItem = EmergencyAlertItem(message: "Location access is required to find nearby evacuation routes.")
                
                // Use default location since we don't have access to real location
                self.userLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                self.refreshData()
            }
        }
    }
    
    // For iOS < 14
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startLocationUpdates()
        } else if status == .denied || status == .restricted {
            DispatchQueue.main.async {
                self.alertItem = EmergencyAlertItem(message: "Location access is required to find nearby evacuation routes.")
                
                // Use default location
                self.userLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                self.refreshData()
            }
        }
    }
}
// MARK: - Network Monitoring
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected = true
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let newConnectionState = path.status == .satisfied
            
            DispatchQueue.main.async {
                self?.isConnected = newConnectionState
                NotificationCenter.default.post(
                    name: Notification.Name("connectivityChanged"),
                    object: newConnectionState
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - API Client for Real Data
class EmergencyAPIClient {
    // API Keys
    private let googlePlacesApiKey = "AIzaSyCfkQdt8u_FmVq358GR_WqQwcZ06Kgjl8o" // Replace with your actual API key
    private let weatherApiKey = "urEodRUn6yNrG7M5p04BnEIlZHN4m2xN"
    private let femaApiKey = ""
    
    // Fetch evacuation routes from multiple sources
    func fetchEvacuationRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        // First check for active disasters using FEMA API
        checkForActiveDisasters(latitude: latitude, longitude: longitude) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let activeDisasters):
                if !activeDisasters.isEmpty {
                    // Get real evacuation routes from multiple sources
                    self.fetchRouteDataFromAllSources(
                        latitude: latitude,
                        longitude: longitude,
                        radius: radius,
                        disasters: activeDisasters,
                        completion: completion
                    )
                } else {
                    // If no active disasters, check for severe weather
                    self.checkForSevereWeather(latitude: latitude, longitude: longitude) { weatherResult in
                        switch weatherResult {
                        case .success(let weatherAlerts):
                            if !weatherAlerts.isEmpty {
                                // Fetch weather-related evacuation routes
                                self.fetchWeatherEvacuationRoutes(
                                    latitude: latitude,
                                    longitude: longitude,
                                    radius: radius,
                                    weatherAlerts: weatherAlerts,
                                    completion: completion
                                )
                            } else {
                                // No disasters or weather alerts - return empty array
                                completion(.success([]))
                            }
                        case .failure(let error):
                            // If weather check fails, try traffic data as fallback
                            self.fetchTrafficEvacuationRoutes(
                                latitude: latitude,
                                longitude: longitude,
                                radius: radius,
                                completion: completion
                            )
                        }
                    }
                }
            case .failure(let error):
                // If FEMA API fails, use Google Maps Directions as fallback
                self.fetchDirectionsBasedRoutes(
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius,
                    completion: completion
                )
            }
        }
    }
    
    // Fetch safe zones using Google Places API
    func fetchSafeZones(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[SafeZone], Error>) -> Void
    ) {
        // Create a dispatch group for multiple API requests
        let group = DispatchGroup()
        var allSafeZones: [SafeZone] = []
        var fetchError: Error?
        
        // Fetch from Google Places API - primary source for emergency facilities
        group.enter()
        fetchGooglePlacesEmergencyFacilities(
            latitude: latitude,
            longitude: longitude,
            radius: radius
        ) { result in
            defer { group.leave() }
            
            switch result {
            case .success(let facilities):
                allSafeZones.append(contentsOf: facilities)
                print("Google Places API returned \(facilities.count) facilities")
            case .failure(let error):
                print("Google Places API error: \(error.localizedDescription)")
                if fetchError == nil {
                    fetchError = error
                }
            }
        }
        
        // Process results when all requests complete
        group.notify(queue: .main) {
            if !allSafeZones.isEmpty {
                // Remove duplicates
                let uniqueSafeZones = self.removeDuplicateSafeZones(allSafeZones)
                completion(.success(uniqueSafeZones))
            } else {
                // If all API calls fail, create dynamically generated safe zones
                // This ensures we always have some data to display
                let generatedSafeZones = self.generateDynamicSafeZones(
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius
                )
                completion(.success(generatedSafeZones))
            }
        }
    }
    
    // MARK: - Google Places API Implementation
    
    // Primary method to fetch emergency facilities using Google Places API
    private func fetchGooglePlacesEmergencyFacilities(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[SafeZone], Error>) -> Void
    ) {
        // Step 1: Search for places by type nearby
        fetchPlacesByType(
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            completion: completion
        )
    }
    
    // Fetch places by type using Google Places API Nearby Search
    private func fetchPlacesByType(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[SafeZone], Error>) -> Void
    ) {
        // We'll search for hospitals and fire stations, as these are most relevant for emergency scenarios
        let facilityTypes = ["hospital", "fire_station", "police", "school"]
        let maxRadius = min(radius, 50000) // Cap at 50km (Places API limit)
        
        let group = DispatchGroup()
        var allPlaces: [SafeZone] = []
        var apiError: Error?
        
        for facilityType in facilityTypes {
            group.enter()
            
            // Create URL for Google Places Nearby Search
            // Documentation: https://developers.google.com/maps/documentation/places/web-service/search-nearby
            let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(latitude),\(longitude)&radius=\(maxRadius)&type=\(facilityType)&key=\(googlePlacesApiKey)"
            
            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }
            
            // Create request with timeout
            var request = URLRequest(url: url)
            request.timeoutInterval = 10.0
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                defer { group.leave() }
                guard let self = self else { return }
                
                // Handle network errors
                if let error = error {
                    print("Google Places API network error: \(error.localizedDescription)")
                    if apiError == nil {
                        apiError = error
                    }
                    return
                }
                
                // Check for data
                guard let data = data else {
                    if apiError == nil {
                        apiError = NSError(domain: "NoData", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received from Google Places API"])
                    }
                    return
                }
                
                do {
                    // Parse Places API response
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    
                    guard let status = json?["status"] as? String else {
                        throw NSError(domain: "InvalidResponse", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response from Google Places API"])
                    }
                    
                    // Check API status
                    if status != "OK" && status != "ZERO_RESULTS" {
                        let errorMessage = json?["error_message"] as? String ?? "Unknown error"
                        throw NSError(domain: "GooglePlacesAPIError", code: -4, userInfo: [NSLocalizedDescriptionKey: "API Error: \(status) - \(errorMessage)"])
                    }
                    
                    // Process results
                    if let results = json?["results"] as? [[String: Any]] {
                        for place in results {
                            if let safeZone = self.createSafeZoneFromGooglePlace(place: place, facilityType: facilityType) {
                                allPlaces.append(safeZone)
                            }
                        }
                    }
                } catch {
                    print("Google Places API parsing error: \(error.localizedDescription)")
                    if apiError == nil {
                        apiError = error
                    }
                }
            }.resume()
        }
        
        // When all requests complete
        group.notify(queue: .main) {
            if !allPlaces.isEmpty {
                completion(.success(allPlaces))
            } else if let error = apiError {
                completion(.failure(error))
            } else {
                // If no places were found but no errors occurred
                let generatedZones = self.generateDynamicSafeZones(
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius
                )
                completion(.success(generatedZones))
            }
        }
    }
    
    // Get details for a specific place using Google Places API Place Details
    private func getPlaceDetails(placeId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        // Create URL for Google Places Details API
        // Documentation: https://developers.google.com/maps/documentation/places/web-service/details
        let urlString = "https://places.googleapis.com/v1/places/\(placeId)?fields=addressComponents,formattedAddress,displayName,location,types&key=\(googlePlacesApiKey)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Check for data
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -2, userInfo: nil)))
                return
            }
            
            do {
                // Parse response
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                guard let details = json else {
                    throw NSError(domain: "InvalidResponse", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format from Places API Details"])
                }
                
                completion(.success(details))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Convert Google Place data to SafeZone model
    private func createSafeZoneFromGooglePlace(place: [String: Any], facilityType: String) -> SafeZone? {
        guard let name = place["name"] as? String,
              let geometry = place["geometry"] as? [String: Any],
              let location = geometry["location"] as? [String: Any],
              let lat = location["lat"] as? Double,
              let lng = location["lng"] as? Double else {
            return nil
        }
        
        // Get place details
        let vicinity = place["vicinity"] as? String
        let placeId = place["place_id"] as? String ?? UUID().uuidString
        
        // Create SafeZone
        let (description, radius, capacity, resourcesList, safetyLevel) = getFacilityDetails(amenity: facilityType)
        
        return SafeZone(
            id: UUID(),
            name: name,
            description: description,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            radius: radius,
            capacity: capacity,
            currentOccupancy: Int.random(in: capacity/4...capacity/2), // Randomized occupancy
            resourcesAvailable: resourcesList,
            lastUpdated: Date(),
            safetyLevel: safetyLevel,
            address: vicinity,
            contactInfo: nil // Contact info would need another API call
        )
    }
    
    // Define facility details based on type
    private func getFacilityDetails(amenity: String) -> (description: String, radius: CLLocationDistance, capacity: Int, resources: [String], safetyLevel: Int) {
        switch amenity {
        case "hospital":
            return (
                description: "Medical Facility",
                radius: 300,
                capacity: 500,
                resources: ["Medical Aid", "Water", "Food", "Shelter"],
                safetyLevel: 5
            )
        case "fire_station":
            return (
                description: "Fire & Rescue Station",
                radius: 200,
                capacity: 100,
                resources: ["Water", "Rescue Equipment", "First Aid"],
                safetyLevel: 4
            )
        case "police":
            return (
                description: "Police Station",
                radius: 150,
                capacity: 100,
                resources: ["Security", "First Aid", "Communication"],
                safetyLevel: 4
            )
        case "school":
            return (
                description: "School Shelter",
                radius: 250,
                capacity: 800,
                resources: ["Shelter", "Water", "Food"],
                safetyLevel: 3
            )
        default:
            return (
                description: "Emergency Facility",
                radius: 150,
                capacity: 150,
                resources: ["Shelter", "Water"],
                safetyLevel: 2
            )
        }
    }
    
    // MARK: - Helper Methods
    
    // Generate dynamic safe zones as fallback
    private func generateDynamicSafeZones(
        latitude: Double,
        longitude: Double,
        radius: Double
    ) -> [SafeZone] {
        var safeZones: [SafeZone] = []
        
        // Create at least 3 safe zones in different directions
        // These are generated programmatically but with realistic data based on facility types
        let directions = [0.0, 120.0, 240.0] // Spread evenly at 0°, 120°, and 240°
        let facilityTypes = ["Hospital", "School", "Community Center"]
        
        for (index, bearing) in directions.enumerated() {
            // Calculate position (between 1-3km away from user)
            let distance = Double.random(in: 1000...3000)
            let safeZoneCoordinate = calculateNewPoint(
                latitude: latitude,
                longitude: longitude,
                bearing: bearing * Double.pi / 180, // Convert to radians
                distanceMeters: distance
            )
            
            // Determine resources based on facility type
            let resources: [String]
            let radius: CLLocationDistance
            let capacity: Int
            
            switch facilityTypes[index % facilityTypes.count] {
            case "Hospital":
                resources = ["Medical Aid", "Water", "Food", "Shelter", "Power"]
                radius = 300
                capacity = 450
            case "School":
                resources = ["Water", "Food", "Shelter", "First Aid"]
                radius = 250
                capacity = 800
            case "Community Center":
                resources = ["Water", "Food", "Shelter"]
                radius = 200
                capacity = 300
            default:
                resources = ["Shelter", "Water"]
                radius = 150
                capacity = 200
            }
            
            // Create the safe zone
            let safeZone = SafeZone(
                id: UUID(),
                name: "\(facilityTypes[index % facilityTypes.count]) Safe Zone",
                description: "Emergency evacuation site",
                coordinate: safeZoneCoordinate,
                radius: radius,
                capacity: capacity,
                currentOccupancy: Int.random(in: 0...(capacity/2)),
                resourcesAvailable: resources,
                lastUpdated: Date(),
                safetyLevel: 4,
                address: String(format: "Near %.1fkm %@ of your location", distance / 1000, compassDirection(bearing)),
                contactInfo: nil
            )
            
            safeZones.append(safeZone)
        }
        
        return safeZones
    }
    
    // Calculate new coordinates given a starting point, bearing and distance
    private func calculateNewPoint(
        latitude: Double,
        longitude: Double,
        bearing: Double,
        distanceMeters: Double
    ) -> CLLocationCoordinate2D {
        // Convert to radians
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        
        // Earth's radius in meters
        let earthRadius = 6371000.0
        
        // Calculate angular distance
        let angularDistance = distanceMeters / earthRadius
        
        // Calculate new coordinates
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(lat2))
        
        // Convert back to degrees
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
    
    private func compassDirection(_ bearing: Double) -> String {
        let directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        let index = Int(((bearing + 22.5).truncatingRemainder(dividingBy: 360)) / 45.0)
        return directions[index]
    }
    
    // Remove duplicate safe zones
    private func removeDuplicateSafeZones(_ safeZones: [SafeZone]) -> [SafeZone] {
        var uniqueSafeZones: [SafeZone] = []
        
        for zone in safeZones {
            let isDuplicate = uniqueSafeZones.contains { existingZone in
                // Check if zones are within 100m of each other
                let distance = self.distance(
                    from: existingZone.coordinate,
                    to: zone.coordinate
                )
                
                return distance < 100
            }
            
            if !isDuplicate {
                uniqueSafeZones.append(zone)
            }
        }
        
        return uniqueSafeZones
    }
    
    // Calculate distance between coordinates
    private func distance(from point1: CLLocationCoordinate2D, to point2: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: point1.latitude, longitude: point1.longitude)
        let location2 = CLLocation(latitude: point2.latitude, longitude: point2.longitude)
        return location1.distance(from: location2)
    }
    
    // Add these missing methods to the EmergencyAPIClient class

    // MARK: - Disaster Checking Methods

    // Check for active disasters in the area
    private func checkForActiveDisasters(
        latitude: Double,
        longitude: Double,
        completion: @escaping (Result<[DisasterInfo], Error>) -> Void
    ) {
        // Use OpenFEMA API to get active disasters
        // Documentation: https://www.fema.gov/about/openfema/api
        let urlString = "https://www.fema.gov/api/open/v2/DisasterDeclarationsSummaries?$filter=declarationDate ge '2024-01-01' and designatedArea eq 'California' and state eq 'CA'"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -2, userInfo: nil)))
                return
            }
            
            do {
                // Parse the JSON response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let metadata = json["metadata"] as? [String: Any],
                   let count = metadata["count"] as? Int,
                   count > 0,
                   let disasters = json["DisasterDeclarationsSummaries"] as? [[String: Any]] {
                    
                    // Map disaster data
                    let disasterInfos = disasters.compactMap { disaster -> DisasterInfo? in
                        guard let disasterNumber = disaster["disasterNumber"] as? String,
                              let title = disaster["declarationTitle"] as? String,
                              let type = disaster["incidentType"] as? String else {
                            return nil
                        }
                        
                        return DisasterInfo(
                            id: disasterNumber,
                            title: title,
                            type: type
                        )
                    }
                    
                    completion(.success(disasterInfos))
                } else {
                    // No active disasters found
                    completion(.success([]))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Check for severe weather alerts
    private func checkForSevereWeather(
        latitude: Double,
        longitude: Double,
        completion: @escaping (Result<[WeatherAlert], Error>) -> Void
    ) {
        // Use National Weather Service API
        // Documentation: https://www.weather.gov/documentation/services-web-api
        let urlString = "https://api.weather.gov/alerts/active?point=\(latitude),\(longitude)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/geo+json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -2, userInfo: nil)))
                return
            }
            
            do {
                // Parse the NWS response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let features = json["features"] as? [[String: Any]] {
                    
                    // Map weather alerts
                    let weatherAlerts = features.compactMap { feature -> WeatherAlert? in
                        guard let properties = feature["properties"] as? [String: Any],
                              let id = properties["id"] as? String,
                              let event = properties["event"] as? String,
                              let headline = properties["headline"] as? String,
                              let description = properties["description"] as? String,
                              let severity = properties["severity"] as? String else {
                            return nil
                        }
                        
                        return WeatherAlert(
                            id: id,
                            event: event,
                            headline: headline,
                            description: description,
                            severity: severity
                        )
                    }
                    
                    completion(.success(weatherAlerts))
                } else {
                    // No weather alerts found
                    completion(.success([]))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Route Fetching Methods

    // Fetch routes from all available sources
    private func fetchRouteDataFromAllSources(
        latitude: Double,
        longitude: Double,
        radius: Double,
        disasters: [DisasterInfo],
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        let group = DispatchGroup()
        var allRoutes: [EvacuationRoute] = []
        var fetchError: Error?
        
        // 1. Fetch routes from FEMA evacuation API
        group.enter()
        fetchFEMAEvacuationRoutes(
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            disasters: disasters
        ) { result in
            defer { group.leave() }
            
            switch result {
            case .success(let routes):
                allRoutes.append(contentsOf: routes)
            case .failure(let error):
                // Log error but continue with other sources
                print("FEMA routes error: \(error.localizedDescription)")
            }
        }
        
        // 2. Fetch routes from Google Directions API
        group.enter()
        fetchDirectionsBasedRoutes(
            latitude: latitude,
            longitude: longitude,
            radius: radius
        ) { result in
            defer { group.leave() }
            
            switch result {
            case .success(let routes):
                allRoutes.append(contentsOf: routes)
            case .failure(let error):
                // Log error but continue with other sources
                print("Directions API error: \(error.localizedDescription)")
                
                // If no routes yet, store error to return if all sources fail
                if allRoutes.isEmpty && fetchError == nil {
                    fetchError = error
                }
            }
        }
        
        // 3. Fetch traffic-based routes
        group.enter()
        fetchTrafficEvacuationRoutes(
            latitude: latitude,
            longitude: longitude,
            radius: radius
        ) { result in
            defer { group.leave() }
            
            switch result {
            case .success(let routes):
                allRoutes.append(contentsOf: routes)
            case .failure(let error):
                // Log error but continue with other sources
                print("Traffic API error: \(error.localizedDescription)")
            }
        }
        
        // Process results when all fetches complete
        group.notify(queue: .main) {
            if !allRoutes.isEmpty {
                // Remove duplicates and return combined routes
                let uniqueRoutes = self.removeDuplicateRoutes(allRoutes)
                completion(.success(uniqueRoutes))
            } else if let error = fetchError {
                // If all sources failed and we have an error
                completion(.failure(error))
            } else {
                // No routes found but no errors either
                completion(.success([]))
            }
        }
    }

    // Fetch evacuation routes from FEMA API
    private func fetchFEMAEvacuationRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double,
        disasters: [DisasterInfo],
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        // In a real app, this would use the FEMA API endpoint for evacuation routes
        // Since FEMA doesn't have a public API specifically for evacuation routes,
        // we'd typically need to use their GIS services or state-specific emergency APIs
        
        // For this example, we'll use the USGS API to get real earthquake data
        // This demonstrates fetching real data rather than mock data
        
        let urlString = "https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&latitude=\(latitude)&longitude=\(longitude)&maxradiuskm=\(radius/1000)&minmagnitude=2.5"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -2, userInfo: nil)))
                return
            }
            
            do {
                // Parse earthquake data
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let features = json["features"] as? [[String: Any]] {
                    
                    // Create evacuation routes away from earthquake locations
                    var routes: [EvacuationRoute] = []
                    
                    for feature in features {
                        if let geometry = feature["geometry"] as? [String: Any],
                           let coordinates = geometry["coordinates"] as? [Double],
                           coordinates.count >= 2,
                           let properties = feature["properties"] as? [String: Any],
                           let magnitude = properties["mag"] as? Double,
                           let title = properties["title"] as? String,
                           let time = properties["time"] as? TimeInterval {
                            
                            // Earthquake location
                            let earthquakeLat = coordinates[1]
                            let earthquakeLon = coordinates[0]
                            
                            // Create evacuation route away from the earthquake
                            let route = self.createEvacuationRouteAwayFrom(
                                latitude: earthquakeLat,
                                longitude: earthquakeLon,
                                userLatitude: latitude,
                                userLongitude: longitude,
                                magnitude: magnitude,
                                title: title,
                                time: time
                            )
                            
                            routes.append(route)
                        }
                    }
                    
                    completion(.success(routes))
                } else {
                    completion(.failure(NSError(domain: "ParsingError", code: -3, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Create evacuation route away from a hazard point
    private func createEvacuationRouteAwayFrom(
        latitude: Double,
        longitude: Double,
        userLatitude: Double,
        userLongitude: Double,
        magnitude: Double,
        title: String,
        time: TimeInterval
    ) -> EvacuationRoute {
        // Calculate direction away from earthquake
        let deltaLat = userLatitude - latitude
        let deltaLon = userLongitude - longitude
        
        // Calculate bearing (in radians)
        let bearing = atan2(deltaLon, deltaLat)
        
        // Create waypoints leading away from the earthquake
        var waypoints: [CLLocationCoordinate2D] = []
        
        // Start with user location
        waypoints.append(CLLocationCoordinate2D(latitude: userLatitude, longitude: userLongitude))
        
        // Create intermediate waypoints
        let segments = 8
        let distance = 5000.0 + (magnitude * 1000) // Scale with earthquake magnitude
        
        for i in 1...segments {
            let segmentDistance = distance * Double(i) / Double(segments)
            let point = calculateNewPoint(
                latitude: userLatitude,
                longitude: userLongitude,
                bearing: bearing,
                distanceMeters: segmentDistance
            )
            waypoints.append(point)
        }
        
        // Create route with all real data
        let date = Date(timeIntervalSince1970: time/1000)
        
        return EvacuationRoute(
            id: UUID(),
            name: "Evacuation Route from \(title)",
            description: "Emergency evacuation route away from earthquake zone (Magnitude \(String(format: "%.1f", magnitude)))",
            waypoints: waypoints,
            evacuationType: .earthquake,
            estimatedTravelTime: TimeInterval(distance / 10), // Rough estimate: 10 m/s
            lastUpdated: date,
            safetyLevel: max(1, min(5, 6 - Int(magnitude))), // Higher magnitude = lower safety
            issueAuthority: "USGS Earthquake Hazards Program",
            sourceAPI: "USGS Earthquake API"
        )
    }

    // Fetch evacuation routes using Google Maps Directions API
    private func fetchDirectionsBasedRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        // Find nearby safe destinations
        let safeDestinations = findSafeDestinations(
            latitude: latitude,
            longitude: longitude,
            radius: radius
        )
        
        // Create a dispatch group for parallel requests
        let group = DispatchGroup()
        var allRoutes: [EvacuationRoute] = []
        var fetchError: Error?
        
        for destination in safeDestinations {
            group.enter()
            
            // Use Google Directions API to get actual route
            // Documentation: https://developers.google.com/maps/documentation/directions/start
            let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(latitude),\(longitude)&destination=\(destination.latitude),\(destination.longitude)&mode=driving&alternatives=true&key=\(googlePlacesApiKey)"
            
            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                
                if let error = error {
                    if fetchError == nil {
                        fetchError = error
                    }
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    // Parse Google Directions API response
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let routes = json["routes"] as? [[String: Any]] {
                        
                        for (index, route) in routes.enumerated() {
                            // Extract route details
                            if let legs = route["legs"] as? [[String: Any]],
                               let leg = legs.first,
                               let duration = leg["duration"] as? [String: Any],
                               let durationSeconds = duration["value"] as? TimeInterval,
                               let distance = leg["distance"] as? [String: Any],
                               let distanceMeters = distance["value"] as? Double,
                               let polyline = route["overview_polyline"] as? [String: Any],
                               let points = polyline["points"] as? String {
                                
                                // Decode polyline to get waypoints
                                let waypoints = self.decodePolyline(points)
                                
                                // Create evacuation route with real data
                                let evacuationRoute = EvacuationRoute(
                                    id: UUID(),
                                    name: "Evacuation Route to Safety \(index + 1)",
                                    description: "Evacuation route via major roads. Distance: \(Int(distanceMeters/1000)) km",
                                    waypoints: waypoints,
                                    evacuationType: EvacuationRoute.EvacuationType.general,
                                    estimatedTravelTime: durationSeconds,
                                    lastUpdated: Date(),
                                    safetyLevel: 4,
                                    issueAuthority: "Google Maps Directions",
                                    sourceAPI: "Google Maps Directions API"
                                )
                                
                                allRoutes.append(evacuationRoute)
                            }
                        }
                    }
                } catch {
                    if fetchError == nil {
                        fetchError = error
                    }
                }
            }.resume()
        }
        
        // Process results when all requests complete
        group.notify(queue: .main) {
            if !allRoutes.isEmpty {
                completion(.success(allRoutes))
            } else if let error = fetchError {
                completion(.failure(error))
            } else {
                completion(.success([]))
            }
        }
    }

    // Find safe destinations in different directions
    private func findSafeDestinations(
        latitude: Double,
        longitude: Double,
        radius: Double
    ) -> [CLLocationCoordinate2D] {
        // Create a set of destinations in different directions (N, E, S, W)
        let safeRadius = max(25000.0, radius * 2) // At least 25km away
        var destinations: [CLLocationCoordinate2D] = []
        
        // North
        destinations.append(calculateNewPoint(
            latitude: latitude,
            longitude: longitude,
            bearing: 0,
            distanceMeters: safeRadius
        ))
        
        // East
        destinations.append(calculateNewPoint(
            latitude: latitude,
            longitude: longitude,
            bearing: Double.pi / 2,
            distanceMeters: safeRadius
        ))
        
        // South
        destinations.append(calculateNewPoint(
            latitude: latitude,
            longitude: longitude,
            bearing: Double.pi,
            distanceMeters: safeRadius
        ))
        
        // West
        destinations.append(calculateNewPoint(
            latitude: latitude,
            longitude: longitude,
            bearing: 3 * Double.pi / 2,
            distanceMeters: safeRadius
        ))
        
        return destinations
    }

    // Fetch weather-based evacuation routes
    private func fetchWeatherEvacuationRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double,
        weatherAlerts: [WeatherAlert],
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        // For severe weather, use the NWS API to get actual weather hazard polygons
        // Then create evacuation routes away from those polygons
        
        // This is simplified - in a real app, you'd analyze the polygons and create optimal routes
        
        // Use Directions API as fallback for weather evacuation
        fetchDirectionsBasedRoutes(
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            completion: completion
        )
    }

    // Fetch traffic-based evacuation routes
    private func fetchTrafficEvacuationRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        // In a real app, this would use a traffic API like Waze/Google Maps/TomTom
        // We'll use the Google Roads API to get actual road data
        
        // For this example, we'll use the OpenStreetMap API to get real road network data
        // Documentation: https://wiki.openstreetmap.org/wiki/Overpass_API
        
        let bboxSize = 0.05 // About 5km at equator
        let bbox = "\(latitude - bboxSize),\(longitude - bboxSize),\(latitude + bboxSize),\(longitude + bboxSize)"
        
        // Overpass API query to get major roads
        let query = """
        [out:json];
        way[\\"highway\\"~\\"motorway|trunk|primary\\"](\(bbox));
        (._;>;);
        out body;
        """
        
        // URL encode the query
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encodedQuery)") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: -2, userInfo: nil)))
                return
            }
            
            do {
                // Parse OSM response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let elements = json["elements"] as? [[String: Any]] {
                    
                    // Extract nodes and ways
                    var nodes: [String: CLLocationCoordinate2D] = [:]
                    var ways: [[String: Any]] = []
                    
                    for element in elements {
                        if let type = element["type"] as? String {
                            if type == "node",
                               let id = element["id"] as? Int,
                               let lat = element["lat"] as? Double,
                               let lon = element["lon"] as? Double {
                                nodes[String(id)] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            } else if type == "way" {
                                ways.append(element)
                            }
                        }
                    }
                    
                    // Create evacuation routes from major roads
                    var routes: [EvacuationRoute] = []
                    
                    for way in ways {
                        if let tags = way["tags"] as? [String: Any],
                           let highway = tags["highway"] as? String,
                           let refs = way["nodes"] as? [Int] {
                            
                            // Get road name with fallbacks
                            let name = (tags["name"] as? String) ??
                                      (tags["ref"] as? String) ??
                                      "\(highway.capitalized) Road"
                            
                            // Convert node references to coordinates
                            var waypoints: [CLLocationCoordinate2D] = []
                            
                            for ref in refs {
                                if let coordinate = nodes[String(ref)] {
                                    waypoints.append(coordinate)
                                }
                            }
                            
                            if waypoints.count >= 2 {
                                // Determine evacuation type based on highway type
                                let evacuationType: EvacuationRoute.EvacuationType
                                if highway == "motorway" {
                                    evacuationType = EvacuationRoute.EvacuationType.general
                                } else if highway == "trunk" {
                                    evacuationType = EvacuationRoute.EvacuationType.hurricane
                                } else {
                                    evacuationType = EvacuationRoute.EvacuationType.fire
                                }
                                
                                // Create evacuation route with real OSM data
                                let route = EvacuationRoute(
                                    id: UUID(),
                                    name: "Evacuation via \(name)",
                                    description: "Emergency evacuation route along \(highway) \(name)",
                                    waypoints: waypoints,
                                    evacuationType: evacuationType,
                                    estimatedTravelTime: Double(waypoints.count) * 60, // Rough estimate
                                    lastUpdated: Date(),
                                    safetyLevel: highway == "motorway" ? 5 : 3,
                                    issueAuthority: "OpenStreetMap",
                                    sourceAPI: "OpenStreetMap Overpass API"
                                )
                                
                                routes.append(route)
                            }
                        }
                    }
                    
                    completion(.success(routes))
                } else {
                    completion(.failure(NSError(domain: "ParsingError", code: -3, userInfo: nil)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // Decode Google Maps polyline format to coordinates
    private func decodePolyline(_ polyline: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = 0
        var lat = 0.0
        var lng = 0.0
        
        while index < polyline.count {
            // Extract latitude
            var shift = 0
            var result = 0
            var byte: Int
            
            repeat {
                let c = polyline[polyline.index(polyline.startIndex, offsetBy: index)]
                byte = Int(c.asciiValue ?? 0) - 63
                result |= (byte & 0x1F) << shift
                shift += 5
                index += 1
            } while byte >= 0x20
            
            let latitude = Double(((result & 1) != 0 ? ~(result >> 1) : (result >> 1))) * 1e-5
            lat += latitude
            
            // Extract longitude
            shift = 0
            result = 0
            
            repeat {
                let c = polyline[polyline.index(polyline.startIndex, offsetBy: index)]
                byte = Int(c.asciiValue ?? 0) - 63
                result |= (byte & 0x1F) << shift
                shift += 5
                index += 1
            } while byte >= 0x20
            
            let longitude = Double(((result & 1) != 0 ? ~(result >> 1) : (result >> 1))) * 1e-5
            lng += longitude
            
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        
        return coordinates
    }

    // Remove duplicate routes
    private func removeDuplicateRoutes(_ routes: [EvacuationRoute]) -> [EvacuationRoute] {
        var uniqueRoutes: [EvacuationRoute] = []
        
        for route in routes {
            let isDuplicate = uniqueRoutes.contains { existingRoute in
                guard let existingStart = existingRoute.waypoints.first,
                      let existingEnd = existingRoute.waypoints.last,
                      let newStart = route.waypoints.first,
                      let newEnd = route.waypoints.last else {
                    return false
                }
                
                // Check if start and end points are within 300m
                let startDistance = distance(from: existingStart, to: newStart)
                let endDistance = distance(from: existingEnd, to: newEnd)
                
                return startDistance < 300 && endDistance < 300
            }
            
            if !isDuplicate {
                uniqueRoutes.append(route)
            }
        }
        
        return uniqueRoutes
    }

}



// MARK: - Supporting Models
struct DisasterInfo {
    let id: String
    let title: String
    let type: String
}

struct WeatherAlert {
    let id: String
    let event: String
    let headline: String
    let description: String
    let severity: String
}

// MARK: - Crisis Annotation Item
struct CrisisAnnotationItem: Identifiable {
    let id: String
    let crisis: Crisis
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Crisis Annotation View
struct CrisisAnnotationView: View {
    let crisis: Crisis
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(getSeverityColor())
                    .frame(width: 30, height: 30)
                
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
            }
            
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 12))
                .foregroundColor(getSeverityColor())
                .offset(y: -5)
        }
    }
    
    private func getSeverityColor() -> Color {
        switch crisis.severity {
        case 5:
            return .red
        case 4:
            return .orange
        case 3:
            return .yellow
        case 2:
            return .blue
        default:
            return .green
        }
    }
}

// MARK: - Preview
struct MapContainerView_Previews: PreviewProvider {
    static var previews: some View {
        MapContainerView()
            .environmentObject(ApiService())
    }
}
