import SwiftUI
import Combine
import AVFoundation
import MapKit
import CoreLocation
import UIKit

// MARK: - Alert Item
struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}

struct ContentView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationView {
                HomeView()
                    .navigationTitle("Dashboard")
            }
            .tabItem {
                Label("Dashboard", systemImage: "house")
            }
            .tag(0)
            
            // Map Tab
            NavigationView {
                MapContainerView()
                    .navigationTitle("Crisis Map")
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            .tag(1)
            
            // Emergency Report Tab (NEW)
            NavigationView {
                EmergencyInputView()
                    .navigationTitle("Report Emergency")
            }
            .tabItem {
                Label("Emergency", systemImage: "exclamationmark.triangle.fill")
            }
            .tag(2)
            
            // Communication Tab
            NavigationView {
                CommunicationView()
                    .navigationTitle("AI Assistant")
            }
            .tabItem {
                Label("Assistant", systemImage: "message.fill")
            }
            .tag(3)
            
            // Alerts Tab
            NavigationView {
                AlertsView()
                    .navigationTitle("Alerts")
            }
            .tabItem {
                Label("Alerts", systemImage: "bell")
            }
            .tag(4)
            
            // Profile Tab
            NavigationView {
                ProfileView()
                    .navigationTitle("Profile")
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
            .tag(5)
        }
        .onAppear {
            // Fetch initial data when app appears
            apiService.fetchInitialData()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ApiService())
    }
}

// MARK: - Emergency Input View
struct EmergencyInputView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var emergencyMessage: String = ""
    @State private var isRecordingVoice: Bool = false
    @State private var showLocationPermissionAlert: Bool = false
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var showAnalysisResult: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showLocationError: Bool = false
    @State private var showMessageStatus: Bool = false
    
    // Location manager
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                emergencyHeader
                
                // Message Status View (shown when sending messages)
                if showMessageStatus {
                    EmergencyMessageStatusView()
                        .environmentObject(apiService)
                        .transition(.opacity)
                }
                
                // Input Section (hidden when showing status)
                if !showMessageStatus {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Describe the Emergency")
                            .font(.headline)
                        
                        ZStack(alignment: .topLeading) {
                            if emergencyMessage.isEmpty && !apiService.isRecognizingSpeech {
                                Text("Provide details about the emergency situation...")
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            
                            TextEditor(text: $emergencyMessage)
                                .frame(minHeight: 150)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        if apiService.isRecognizingSpeech {
                            Text("Listening: \(apiService.recognizedSpeech)")
                                .foregroundColor(.blue)
                                .padding(.vertical, 5)
                        }
                        
                        // Input Controls
                        HStack {
                            Button(action: {
                                toggleVoiceRecording()
                            }) {
                                HStack {
                                    Image(systemName: isRecordingVoice ? "stop.circle.fill" : "mic.circle.fill")
                                    Text(isRecordingVoice ? "Stop Recording" : "Voice Input")
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 15)
                                .background(isRecordingVoice ? Color.red.opacity(0.8) : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                clearInputs()
                            }) {
                                Text("Clear")
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 15)
                                    .background(Color.gray.opacity(0.3))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // Location Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your Location")
                            .font(.headline)
                        
                        if let errorMessage = locationManager.locationError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(errorMessage)
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            .padding(.bottom, 4)
                        }
                        
                        if let location = locationManager.lastLocation?.coordinate {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text(locationManager.locationError == nil ? "Location available" : "Using approximate location")
                                    .foregroundColor(locationManager.locationError == nil ? .green : .orange)
                                Spacer()
                            }
                            
                            // Updated Map implementation for iOS 17+
                            Group {
                                if #available(iOS 17.0, *) {
                                    Map {
                                        UserAnnotation()
                                        Marker("Your Location", coordinate: location)
                                            .tint(.blue)
                                    }
                                    .mapStyle(.standard)
                                    .mapControls {
                                        MapUserLocationButton()
                                        MapCompass()
                                    }
                                    .frame(height: 150)
                                    .cornerRadius(8)
                                } else {
                                    // Fallback for older iOS versions
                                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                                        center: location,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    )), showsUserLocation: true, userTrackingMode: .constant(.follow))
                                    .frame(height: 150)
                                    .cornerRadius(8)
                                }
                            }
                            .onAppear {
                                currentLocation = location
                            }
                        } else {
                            HStack {
                                Image(systemName: "location.slash.fill")
                                    .foregroundColor(.orange)
                                Text("Location not available")
                                    .foregroundColor(.orange)
                                Spacer()
                                
                                Button(action: {
                                    requestLocationPermission()
                                }) {
                                    Text("Enable")
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 10)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(5)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // Submit Button
                    Button(action: {
                        submitEmergencyReport()
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Submit Emergency Report")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            emergencyMessage.isEmpty ? Color.gray : Color.red
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    }
                    .disabled(emergencyMessage.isEmpty || isSubmitting)
                    .padding(.top, 10)
                    
                    if isSubmitting {
                        ProgressView("Processing emergency report...")
                            .padding()
                    }
                }
                
                // Analysis Results
                if showAnalysisResult, let analysis = apiService.emergencyAnalysis {
                    EmergencyResultView(
                        analysis: analysis,
                        messageResponse: apiService.emergencyServiceResponse
                    )
                    .environmentObject(apiService)
                    .transition(.opacity)
                    
                    // Done & New Report buttons
                    HStack {
                        Button(action: {
                            // Return to dashboard
                            clearInputs()
                        }) {
                            Text("Done")
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // Clear form for new report
                            resetForm()
                        }) {
                            Text("New Report")
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 10)
                }
            }
            .padding()
        }
        .onAppear {
            // Request location and speech permissions on view appear
            locationManager.requestAuthorization()
            Task {
                _ = await apiService.requestSpeechRecognitionPermission()
            }
        }
        .onChange(of: locationManager.lastLocation) { newLocation in
            if let location = newLocation?.coordinate {
                currentLocation = location
            }
        }
        // Fix: Use onChange with a value that's not optional and properly observe messageStatus changes
        .onChange(of: apiService.isMessageSending) { isMessageSending in
            if let status = apiService.messageStatus {
                switch status {
                case .delivered:
                    // When message is delivered, show the analysis results
                    withAnimation {
                        showMessageStatus = false
                        showAnalysisResult = true
                    }
                case .failed:
                    // If message fails, show error and reset
                    withAnimation {
                        showMessageStatus = false
                        isSubmitting = false
                    }
                default:
                    break
                }
            }
        }
        .alert(isPresented: $showLocationPermissionAlert) {
            Alert(
                title: Text("Location Access"),
                message: Text("Location access is important for emergency services to reach you. Please enable location services in your device settings."),
                primaryButton: .default(Text("Settings"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
        .alert(item: alertItem) { alertItem in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var alertItem: Binding<AlertItem?> {
        Binding<AlertItem?>(
            get: {
                if let error = apiService.emergencyError {
                    return AlertItem(message: error)
                }
                return nil
            },
            set: { _ in
                apiService.emergencyError = nil
            }
        )
    }
    
    private var emergencyHeader: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Emergency Report")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Report an emergency situation for immediate assistance")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func requestLocationPermission() {
        locationManager.requestAuthorization()
        
        // Check if we need to show settings alert
        if locationManager.authorizationStatus == .denied ||
           locationManager.authorizationStatus == .restricted {
            showLocationPermissionAlert = true
        }
    }
    
    private func toggleVoiceRecording() {
        if isRecordingVoice {
            // Stop recording
            apiService.stopSpeechRecognition()
            isRecordingVoice = false
            
            // Update text field with recognized speech
            if !apiService.recognizedSpeech.isEmpty {
                emergencyMessage = apiService.recognizedSpeech
                apiService.recognizedSpeech = ""
            }
        } else {
            // Start recording
            apiService.startSpeechRecognition()
            isRecordingVoice = true
        }
    }
    
    private func clearInputs() {
        emergencyMessage = ""
        apiService.recognizedSpeech = ""
        showAnalysisResult = false
        showMessageStatus = false
    }
    
    private func resetForm() {
        clearInputs()
        // Reset the API service state for a new report
        apiService.emergencyAnalysis = nil
        apiService.situationAnalysis = nil
        apiService.emergencyMessage = nil
        apiService.emergencyServiceResponse = nil
    }
    
    private func submitEmergencyReport() {
        guard !emergencyMessage.isEmpty else { return }
        
        isSubmitting = true
        
        Task {
            // This will analyze the emergency, create a formatted message, and send it to services
            let success = await apiService.submitEmergencyReport(
                message: emergencyMessage,
                location: currentLocation
            )
            
            // Show the message sending status
            DispatchQueue.main.async {
                withAnimation {
                    showMessageStatus = true
                    isSubmitting = false
                }
            }
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isInitialized = false
    
    // Default location to use when actual location is unavailable
    let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    
    override init() {
        super.init()
        
        // Configure location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        
        // Initialize with current authorization status
        if #available(iOS 14.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        
        // Dispatch to background queue to avoid main thread warning
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.checkAndStartUpdatingLocationIfAuthorized()
            
            DispatchQueue.main.async {
                self?.isInitialized = true
            }
        }
    }
    
    func requestAuthorization() {
        // Only request authorization if we haven't already
        if authorizationStatus == .notDetermined {
            // Always do this on main thread to avoid warnings
            DispatchQueue.main.async { [weak self] in
                self?.locationManager.requestWhenInUseAuthorization()
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            // If authorization is denied, notify and use default location
            self.locationError = "Location permission denied. Using default location."
            self.lastLocation = defaultLocation
        } else {
            // If already authorized, start updates
            startUpdatingLocation()
        }
    }
    
    func startUpdatingLocation() {
        if CLLocationManager.locationServicesEnabled() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                DispatchQueue.main.async {
                    self?.locationManager.startUpdatingLocation()
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.locationError = "Location services are disabled. Using default location."
                self.lastLocation = self.defaultLocation
            }
        }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    private func checkAndStartUpdatingLocationIfAuthorized() {
        let status: CLAuthorizationStatus
        
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdatingLocation()
        } else if status == .denied || status == .restricted {
            // Use default location if permissions denied
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.locationError = "Location access not granted. Using default location."
                self.lastLocation = self.defaultLocation
            }
        }
    }
    
    // MARK: CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if accuracy is reasonable
        if location.horizontalAccuracy >= 0 {
            DispatchQueue.main.async { [weak self] in
                self?.lastLocation = location
                self?.locationError = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        // Handle different error types
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.locationError = "Location access denied. Using default location."
                    self.lastLocation = self.defaultLocation
                }
            case .locationUnknown:
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.locationError = "Unable to determine location. Using last known or default location."
                    if self.lastLocation == nil {
                        self.lastLocation = self.defaultLocation
                    }
                }
            default:
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.locationError = "Location error: \(error.localizedDescription). Using default location."
                    if self.lastLocation == nil {
                        self.lastLocation = self.defaultLocation
                    }
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.locationError = "Location error: \(error.localizedDescription). Using default location."
                if self.lastLocation == nil {
                    self.lastLocation = self.defaultLocation
                }
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if #available(iOS 14.0, *) {
                self.authorizationStatus = manager.authorizationStatus
            } else {
                self.authorizationStatus = CLLocationManager.authorizationStatus()
            }
        }
        
        checkAndStartUpdatingLocationIfAuthorized()
    }
    
    // For iOS < 14
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
        }
        
        checkAndStartUpdatingLocationIfAuthorized()
    }
}

// MARK: - OpenStreetMap Route Finder Implementation
// MARK: - OpenStreetMapRouteFinder Implementation
class OpenStreetMapRouteFinder {
    // Fetch evacuation routes using OpenStreetMap API
    func fetchEvacuationRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        print("Fetching evacuation routes from OpenStreetMap for location: \(latitude),\(longitude)")
        
        // Create multiple parallel requests for different types of routes
        let group = DispatchGroup()
        var allRoutes: [EvacuationRoute] = []
        var fetchError: Error?
        
        // 1. Fetch major roads for evacuation
        group.enter()
        fetchMajorRoads(latitude: latitude, longitude: longitude, radius: radius) { result in
            defer { group.leave() }
            
            switch result {
            case .success(let routes):
                allRoutes.append(contentsOf: routes)
                print("OpenStreetMap major roads: Found \(routes.count) routes")
            case .failure(let error):
                print("OpenStreetMap major roads error: \(error.localizedDescription)")
                if fetchError == nil {
                    fetchError = error
                }
            }
        }
        
        // Process results when all fetches complete
        group.notify(queue: .main) {
            if !allRoutes.isEmpty {
                // Get unique routes, prioritizing emergency routes
                let uniqueRoutes = self.removeDuplicateRoutes(allRoutes)
                print("Final OpenStreetMap routes: Using \(uniqueRoutes.count) routes")
                completion(.success(uniqueRoutes))
            } else if let error = fetchError {
                // All fetches failed with errors
                completion(.failure(error))
            } else {
                // Fallback: Generate some directional routes
                let fallbackRoutes = self.generateDirectionalRoutes(latitude: latitude, longitude: longitude, radius: radius)
                print("Using \(fallbackRoutes.count) fallback directional routes")
                completion(.success(fallbackRoutes))
            }
        }
    }
    
    // Fetch major roads that can serve as evacuation routes
    private func fetchMajorRoads(
        latitude: Double,
        longitude: Double,
        radius: Double,
        completion: @escaping (Result<[EvacuationRoute], Error>) -> Void
    ) {
        // Calculate bounding box (use smaller radius to avoid huge queries)
        let radiusInDegrees = min(0.1, radius / 111000.0) // Cap at 0.1 degrees (~11km)
        let bbox = "\(longitude-radiusInDegrees),\(latitude-radiusInDegrees),\(longitude+radiusInDegrees),\(latitude+radiusInDegrees)"
        
        // Simplified OpenStreetMap Overpass API query - focus only on major highways
        let query = """
        [out:json][timeout:15];
        (
          // Just major roads suitable for evacuation
          way["highway"~"motorway|trunk|primary"](\(bbox));
        );
        // Include nodes to reconstruct paths
        (._;>;);
        out body;
        """
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://overpass-api.de/api/interpreter?data=\(encodedQuery)") else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        // Create request with shorter timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network errors
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
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let elements = json["elements"] as? [[String: Any]] else {
                    completion(.failure(NSError(domain: "InvalidJSON", code: -3, userInfo: nil)))
                    return
                }
                
                // Dictionary to store node coordinates
                var nodes: [String: CLLocationCoordinate2D] = [:]
                
                // Extract all nodes first
                for element in elements {
                    if let type = element["type"] as? String, type == "node",
                       let id = element["id"] as? Int,
                       let lat = element["lat"] as? Double,
                       let lon = element["lon"] as? Double {
                        nodes[String(id)] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                }
                
                // Process ways to create evacuation routes
                var routes: [EvacuationRoute] = []
                let userLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                
                for element in elements {
                    if let type = element["type"] as? String, type == "way",
                       let id = element["id"] as? Int,
                       let nodeRefs = element["nodes"] as? [Int],
                       let tags = element["tags"] as? [String: Any],
                       nodeRefs.count >= 2 {
                        
                        // Get highway type
                        guard let highway = tags["highway"] as? String else { continue }
                        
                        // Convert node IDs to coordinates
                        var waypoints: [CLLocationCoordinate2D] = []
                        for nodeRef in nodeRefs {
                            if let coordinate = nodes[String(nodeRef)] {
                                waypoints.append(coordinate)
                            }
                        }
                        
                        if waypoints.count < 2 { continue }
                        
                        // Get road name with fallbacks
                        let name = (tags["name"] as? String) ??
                                  (tags["ref"] as? String) ??
                                  "\(highway.capitalized) Road"
                        
                        // Simplified safety level and speed calculations
                        let safetyLevel: Int
                        let speedMS: Double
                        
                        switch highway {
                        case "motorway":
                            safetyLevel = 4; speedMS = 16.7  // ~60 km/h
                        case "trunk":
                            safetyLevel = 4; speedMS = 13.9  // ~50 km/h
                        case "primary":
                            safetyLevel = 3; speedMS = 11.1  // ~40 km/h
                        default:
                            safetyLevel = 2; speedMS = 8.3   // ~30 km/h
                        }
                        
                        // Calculate total route distance
                        var totalDistance: CLLocationDistance = 0
                        for i in 0..<(waypoints.count - 1) {
                            let from = CLLocation(latitude: waypoints[i].latitude, longitude: waypoints[i].longitude)
                            let to = CLLocation(latitude: waypoints[i+1].latitude, longitude: waypoints[i+1].longitude)
                            totalDistance += from.distance(from: to)
                        }
                        
                        // Calculate estimated travel time
                        let estimatedTimeSeconds = totalDistance / speedMS
                        
                        // Get appropriate evacuation direction description
                        let directionDescription = self.getRouteDirectionDescription(
                            from: userLocation,
                            to: waypoints.last ?? waypoints.first!
                        )
                        
                        // Create evacuation route with real road data
                        let route = EvacuationRoute(
                            id: UUID(),
                            name: "Evacuation via \(name)",
                            description: "Evacuation route \(directionDescription) along \(highway) \(name)",
                            waypoints: waypoints,
                            evacuationType: .general,
                            estimatedTravelTime: estimatedTimeSeconds,
                            lastUpdated: Date(),
                            safetyLevel: safetyLevel,
                            issueAuthority: "OpenStreetMap",
                            sourceAPI: "OpenStreetMap"
                        )
                        
                        routes.append(route)
                    }
                }
                
                // Limit to most relevant routes (max 5)
                let sortedRoutes = routes.sorted { $0.safetyLevel > $1.safetyLevel }
                let limitedRoutes = Array(sortedRoutes.prefix(5))
                completion(.success(limitedRoutes))
                
            } catch {
                print("OpenStreetMap parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Generate directional evacuation routes if API calls fail
    private func generateDirectionalRoutes(
        latitude: Double,
        longitude: Double,
        radius: Double
    ) -> [EvacuationRoute] {
        var routes: [EvacuationRoute] = []
        
        // Create routes in cardinal directions (N, NE, E, SE, S, SW, W, NW)
        let bearings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
        let directions = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
        
        // User's starting location
        let startPoint = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        for (index, bearing) in bearings.enumerated() {
            // Create waypoints along the bearing
            var waypoints: [CLLocationCoordinate2D] = []
            
            // Start with user location
            waypoints.append(startPoint)
            
            // Create a series of points in the given direction
            for distance in stride(from: 500.0, through: 10000.0, by: 500.0) {
                let point = self.calculateNewPoint(
                    latitude: latitude,
                    longitude: longitude,
                    bearing: bearing * .pi / 180.0, // Convert to radians
                    distanceMeters: distance
                )
                waypoints.append(point)
            }
            
            // Create the evacuation route
            let route = EvacuationRoute(
                id: UUID(),
                name: "Evacuation Route \(directions[index])",
                description: "Evacuation route heading \(directions[index]) from your location",
                waypoints: waypoints,
                evacuationType: .general,
                estimatedTravelTime: 10000.0 / 10.0, // Assuming 10 m/s average speed
                lastUpdated: Date(),
                safetyLevel: 3,
                issueAuthority: "Generated Evacuation Route",
                sourceAPI: "Directional Algorithm"
            )
            
            routes.append(route)
        }
        
        return routes
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
    
    // Get human-readable direction description
    private func getRouteDirectionDescription(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> String {
        let deltaLat = end.latitude - start.latitude
        let deltaLon = end.longitude - start.longitude
        
        // Calculate bearing in radians
        let bearing = atan2(deltaLon, deltaLat)
        
        // Convert to degrees (0-360)
        let bearingDegrees = (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        
        // Convert bearing to cardinal direction
        let directions = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest", "north"]
        let index = Int(round(bearingDegrees / 45.0))
        
        return "to the \(directions[index])"
    }
    
    // Remove duplicate routes
    private func removeDuplicateRoutes(_ routes: [EvacuationRoute]) -> [EvacuationRoute] {
        var uniqueRoutes: [EvacuationRoute] = []
        var processedDirections = Set<String>()
        
        // First, add all official evacuation routes
        let officialRoutes = routes.filter { $0.issueAuthority.contains("Official") }
        uniqueRoutes.append(contentsOf: officialRoutes)
        
        // For each official route, record its general direction
        for route in officialRoutes {
            if let start = route.waypoints.first, let end = route.waypoints.last {
                let direction = getRouteDirectionDescription(from: start, to: end)
                processedDirections.insert(direction)
            }
        }
        
        // Then add other routes only if they're in a different direction
        for route in routes {
            if route.issueAuthority.contains("Official") {
                continue // Already added
            }
            
            if let start = route.waypoints.first, let end = route.waypoints.last {
                let direction = getRouteDirectionDescription(from: start, to: end)
                
                if !processedDirections.contains(direction) {
                    uniqueRoutes.append(route)
                    processedDirections.insert(direction)
                }
            }
        }
        
        return uniqueRoutes
    }
}

// MARK: - Alert View
struct AlertsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Alerts and Notifications")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("You'll see important alerts and notifications here.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
        .padding()
    }
}

// MARK: - Profile View
struct ProfileView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("User Profile")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Your profile information and settings will appear here.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
            
            Button("Sign In") {
                // Sign in functionality would go here
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: AIMessage
    
    var isUser: Bool {
        message.role == "user"
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer() }
            
            Text(message.content)
                .padding(12)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(isUser ? .white : .primary)
                .cornerRadius(16)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
            
            if !isUser { Spacer() }
        }
    }
}

// MARK: - Communication View
struct CommunicationView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var messageText: String = ""
    @State private var isRecording: Bool = false
    @State private var showAISelector: Bool = false
    @State private var selectedAI: AIType = .claude
    @State private var isTranslating: Bool = false
    @State private var isProcessing: Bool = false
    
    // Add AudioRecorderManager to handle recording functionality
    @StateObject private var audioRecorderManager = AudioRecorderManager()
    
    enum AIType {
        case claude, gpt
    }
    
    var body: some View {
        VStack {
            // AI Selection Header
            HStack {
                Text("Current AI: ")
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showAISelector.toggle()
                }) {
                    HStack {
                        Text(selectedAI == .claude ? "Claude" : "GPT")
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .actionSheet(isPresented: $showAISelector) {
                    ActionSheet(
                        title: Text("Select AI Assistant"),
                        buttons: [
                            .default(Text("Claude")) { selectedAI = .claude },
                            .default(Text("GPT")) { selectedAI = .gpt },
                            .cancel()
                        ]
                    )
                }
                
                Spacer()
                
                Button(action: {
                    apiService.clearConversation()
                }) {
                    Text("Clear Chat")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Chat Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(apiService.currentConversation.indices, id: \.self) { index in
                        let message = apiService.currentConversation[index]
                        MessageBubble(message: message)
                    }
                    
                    if apiService.isProcessingAI {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
                .padding()
            }
            
            // Input Controls
            VStack(spacing: 8) {
                if isTranslating {
                    HStack {
                        Text("Translating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            isTranslating = false
                        }) {
                            Text("Cancel")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack {
                    // Voice Input Button
                    Button(action: {
                        toggleVoiceRecording()
                    }) {
                        Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isRecording ? .red : .blue)
                            .padding(8)
                    }
                    
                    // Text Input Field
                    TextField("Message", text: $messageText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    
                    // Send Button
                    Button(action: {
                        sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiService.isProcessingAI)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 2)
        }
        .alert(item: aiAlertItem) { alertItem in
            Alert(
                title: Text("Error"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: audioRecorderManager.transcribedText) { newValue in
            if !newValue.isEmpty {
                messageText = newValue
            }
        }
        .onChange(of: audioRecorderManager.errorMessage) { newValue in
            if let error = newValue {
                apiService.aiErrorMessage = error
            }
        }
        .onChange(of: audioRecorderManager.isRecording) { newValue in
            isRecording = newValue
        }
    }
    
    private var aiAlertItem: Binding<AlertItem?> {
        Binding<AlertItem?>(
            get: {
                if let error = apiService.aiErrorMessage {
                    return AlertItem(message: error)
                }
                return nil
            },
            set: { _ in
                apiService.aiErrorMessage = nil
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func toggleVoiceRecording() {
        if isRecording {
            audioRecorderManager.stopRecording()
            isProcessing = true
            
            // Process the recorded audio
            Task {
                await audioRecorderManager.processAudioToText(with: apiService)
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        } else {
            audioRecorderManager.startRecording()
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedMessage.isEmpty {
            Task {
                // Send to appropriate AI service
                let response: String?
                
                if selectedAI == .claude {
                    response = await apiService.sendMessageToClaude(userMessage: trimmedMessage)
                } else {
                    response = await apiService.sendMessageToGPT(userMessage: trimmedMessage)
                }
                
                // Clear message field
                DispatchQueue.main.async {
                    self.messageText = ""
                }
            }
        }
    }
}

// MARK: - Audio Recorder Manager
// This class handles audio recording and implements AVAudioRecorderDelegate
class AudioRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording: Bool = false
    @Published var transcribedText: String = ""
    @Published var errorMessage: String? = nil
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL? = nil
    
    func startRecording() {
        // Reset state
        transcribedText = ""
        errorMessage = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            // Configure audio settings
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Get the documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            audioFileURL = documentsPath.appendingPathComponent("recording.m4a")
            
            guard let fileURL = audioFileURL else {
                setError("Could not create audio file URL")
                return
            }
            
            // Create and configure the audio recorder
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            
            if audioRecorder?.record() == true {
                DispatchQueue.main.async {
                    self.isRecording = true
                }
            } else {
                setError("Failed to start recording")
            }
        } catch {
            setError("Recording error: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    func processAudioToText(with apiService: ApiService) async {
        guard let fileURL = audioFileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            setError("No recording found")
            return
        }
        
        do {
            // Read the audio data
            let audioData = try Data(contentsOf: fileURL)
            
            // Send to speech-to-text service
            if let transcribedText = await apiService.processVoiceToText(audioData: audioData) {
                DispatchQueue.main.async {
                    self.transcribedText = transcribedText
                }
            } else {
                setError("Failed to transcribe audio")
            }
        } catch {
            setError("Error processing audio: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVAudioRecorderDelegate methods
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            setError("Recording failed to complete successfully")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        setError("Recording error: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    // MARK: - Helper methods
    
    private func setError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isRecording = false
        }
    }
}

// MARK: - Emergency Result View
struct EmergencyResultView: View {
    @EnvironmentObject var apiService: ApiService
    let analysis: EmergencyAnalysisResponse
    let messageResponse: EmergencyServiceResponse?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Analysis Header
            HStack {
                Text("Emergency Analysis")
                    .font(.headline)
                
                Spacer()
                
                // Urgency badge
                Text(analysis.urgency)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(urgencyColor(for: analysis.urgency).opacity(0.2))
                    .foregroundColor(urgencyColor(for: analysis.urgency))
                    .cornerRadius(4)
            }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
            
            // Severity rating
            HStack {
                Text("Severity:")
                    .fontWeight(.medium)
                
                Spacer()
                
                // Star rating
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { level in
                        Image(systemName: level <= analysis.severity ? "circle.fill" : "circle")
                            .foregroundColor(level <= analysis.severity ? .red : .gray)
                    }
                }
            }
            
            // Emergency type
            HStack {
                Text("Type:")
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(analysis.category)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            // Recommended actions
            if !analysis.recommendedActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Actions:")
                        .fontWeight(.medium)
                    
                    ForEach(analysis.recommendedActions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding(.top, 2)
                            
                            Text(action)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            // Affected area
            if let area = analysis.estimatedAffectedArea {
                HStack {
                    Text("Estimated Affected Area:")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f sq km", area))
                        .font(.body)
                }
            }
            
            // Emergency Services Response
            if let response = messageResponse {
                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Emergency Services Notified")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text(response.message)
                        .font(.subheadline)
                    
                    if let eta = response.estimatedResponseTime {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            
                            Text("Estimated Response Time: \(eta) minutes")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let actions = response.actions, !actions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Instructions:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ForEach(actions, id: \.self) { action in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.blue)
                                        .padding(.top, 2)
                                    
                                    Text(action)
                                        .font(.subheadline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                    
                    // Reference ID
                    HStack {
                        Text("Reference ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(response.messageId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding()
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 1)
                )
            }
            
            // Call emergency services button
            Button(action: {
                callEmergencyServices()
            }) {
                HStack {
                    Image(systemName: "phone.fill")
                    Text("Call Emergency Services")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Helper Methods
    
    private func urgencyColor(for urgency: String) -> Color {
        switch urgency.lowercased() {
        case _ where urgency.contains("immediate"):
            return .red
        case _ where urgency.contains("urgent"):
            return .orange
        case _ where urgency.contains("soon"):
            return .yellow
        default:
            return .blue
        }
    }
    
    private func callEmergencyServices() {
        // In a real app, this would use the appropriate emergency number based on location
        guard let url = URL(string: "tel://911") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Emergency Message Status View
struct EmergencyMessageStatusView: View {
    @EnvironmentObject var apiService: ApiService
    
    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                if apiService.isMessageSending {
                    // Show spinner when sending
                    ProgressView()
                        .scaleEffect(1.5)
                } else if case .delivered = apiService.messageStatus {
                    // Show checkmark when delivered
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                } else if case .failed = apiService.messageStatus {
                    // Show error when failed
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }
            }
            
            // Status text
            Text(statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            // Details
            Text(statusDetails)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // Status text based on current status
    private var statusText: String {
        guard let status = apiService.messageStatus else {
            return "Preparing message..."
        }
        
        switch status {
        case .preparing:
            return "Preparing emergency message..."
        case .sending:
            return "Contacting emergency services..."
        case .delivered:
            return "Emergency services notified!"
        case .failed:
            return "Failed to contact emergency services"
        }
    }
    
    // More detailed explanation based on status
    private var statusDetails: String {
        guard let status = apiService.messageStatus else {
            return "Your emergency information is being formatted for services."
        }
        
        switch status {
        case .preparing:
            return "Your emergency details are being prepared for submission to emergency services."
        case .sending:
            return "Your emergency report is being securely transmitted to emergency services."
        case .delivered(let messageId, let timestamp):
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return "Emergency services received your report at \(formatter.string(from: timestamp)). Reference ID: \(messageId)"
        case .failed(let error):
            return "Error: \(error.localizedDescription). Please try again or call emergency services directly."
        }
    }
}
