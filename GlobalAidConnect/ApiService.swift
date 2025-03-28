import Foundation
import Combine
import SwiftUI
import AVFoundation
import Speech
import CoreLocation

// MARK: - Data Models
struct Crisis: Identifiable, Codable {
    let id: String
    let name: String
    let location: String
    let severity: Int // 1-5
    let startDate: Date
    let description: String
    let affectedPopulation: Int
    let coordinatorContact: String?
    let coordinates: Coordinates?
}

struct Coordinates: Codable {
    let latitude: Double
    let longitude: Double
}

struct Update: Identifiable, Codable {
    let id: String
    let crisisId: String
    let title: String
    let content: String
    let timestamp: Date
    let source: String
}

// MARK: - Emergency Models
struct EmergencyReport {
    let id: String = UUID().uuidString
    let timestamp: Date = Date()
    let message: String
    let location: CLLocationCoordinate2D?
    let severity: Int?
    let category: String?
    let isProcessed: Bool
}

struct EmergencyAnalysisResponse: Codable {
    let severity: Int
    let category: String
    let urgency: String
    let recommendedActions: [String]
    let estimatedAffectedArea: Double?
}

// MARK: - Situation Analysis Models
struct SituationAnalysis: Codable {
    let urgency: EmergencyUrgency
    let type: String
    let severity: Int
    let locationHints: [String]
    let recommendedActions: [String]
    let potentialRisks: [String]
    let affectedArea: AffectedArea?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case urgency, type, severity, locationHints, recommendedActions, potentialRisks, affectedArea
        case timestamp
    }
}

enum EmergencyUrgency: String, Codable {
    case immediate = "immediate"
    case urgent = "urgent"
    case moderate = "moderate"
    case low = "low"
    
    var description: String {
        switch self {
        case .immediate: return "Immediate Response Required"
        case .urgent: return "Urgent Response Required"
        case .moderate: return "Response Required Soon"
        case .low: return "Response Can Be Scheduled"
        }
    }
    
    var color: Color {
        switch self {
        case .immediate: return .red
        case .urgent: return .orange
        case .moderate: return .yellow
        case .low: return .blue
        }
    }
}

struct AffectedArea: Codable {
    let radius: Double // in kilometers
    let estimatedPopulation: Int?
    let terrainType: String?
}

// MARK: - AI Models
struct AIMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeRequest: Codable {
    let model: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct GPTRequest: Codable {
    let model: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int
    let responseFormat: ResponseFormat?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

struct ResponseFormat: Codable {
    let type: String
}

struct AIResponse: Codable {
    let id: String
    let choices: [AIChoice]
}

struct AIChoice: Codable {
    let message: AIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

// MARK: - NASA EONET API Models
struct EONETResponse: Codable {
    let title: String
    let description: String
    let events: [EONETEvent]
}

struct EONETEvent: Codable {
    let id: String
    let title: String
    let description: String?
    let closed: String?
    let categories: [EONETCategory]
    let sources: [EONETSource]
    let geometry: [EONETGeometry]
}

struct EONETCategory: Codable {
    let id: String
    let title: String
}

struct EONETSource: Codable {
    let id: String
    let url: String
}

struct EONETGeometry: Codable {
    let date: String
    let type: String
    let coordinates: [Double]
}

// Add this code to the beginning of ApiService.swift, after the existing model declarations
// and before the ApiService class implementation

// MARK: - Emergency Messaging Models
struct LocationData: Codable {
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let regionName: String?
    
    init(latitude: Double? = nil,
         longitude: Double? = nil,
         address: String? = nil,
         regionName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.regionName = regionName
    }
}

struct UserInfo: Codable {
    let id: String
    let name: String?
    let contactPhone: String?
    let medicalNeeds: String?
    
    init(id: String = UUID().uuidString,
         name: String? = nil,
         contactPhone: String? = nil,
         medicalNeeds: String? = nil) {
        self.id = id
        self.name = name
        self.contactPhone = contactPhone
        self.medicalNeeds = medicalNeeds
    }
}

// Define AppInfo before it's used in EmergencyMessage
struct AppInfo: Codable {
    let appId: String
    let version: String
    let platform: String
    
    init(appId: String = "com.globalaidconnect.app",
         version: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
         platform: String = "iOS") {
        self.appId = appId
        self.version = version
        self.platform = platform
    }
}

struct EmergencyMessage: Codable {
    let id: String
    let timestamp: Date
    let emergencyType: String
    let urgency: String
    let severity: Int
    let description: String
    let location: LocationData
    let userInfo: UserInfo
    let actions: [String]
    let appInfo: AppInfo
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, emergencyType, urgency, severity, description, location, userInfo, actions, appInfo
    }
    
    init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        emergencyType: String,
        urgency: String,
        severity: Int,
        description: String,
        location: LocationData,
        userInfo: UserInfo,
        actions: [String],
        appInfo: AppInfo = AppInfo()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.emergencyType = emergencyType
        self.urgency = urgency
        self.severity = severity
        self.description = description
        self.location = location
        self.userInfo = userInfo
        self.actions = actions
        self.appInfo = appInfo
    }
}

struct EmergencyServiceResponse: Codable {
    let success: Bool
    let messageId: String
    let responseCode: String
    let estimatedResponseTime: Int?
    let message: String
    let actions: [String]?
}

// MARK: - API Service
class ApiService: ObservableObject {
    // Published properties for real-time data
    @Published var activeCrises: [Crisis]? = nil
    @Published var recentUpdates: [Update]? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Published properties for AI responses
    @Published var isProcessingAI: Bool = false
    @Published var currentConversation: [AIMessage] = []
    @Published var aiErrorMessage: String? = nil
    
    // Published properties for emergency reporting
    @Published var currentEmergency: EmergencyReport? = nil
    @Published var emergencyAnalysis: EmergencyAnalysisResponse? = nil
    @Published var isProcessingEmergency: Bool = false
    @Published var emergencyError: String? = nil
    @Published var recognizedSpeech: String = ""
    @Published var isRecognizingSpeech: Bool = false
    
    // Published properties for situation analysis
    @Published var situationAnalysis: SituationAnalysis? = nil
    @Published var isProcessingSituation: Bool = false
    @Published var situationError: String? = nil
    
    // Published properties for emergency messaging
    @Published var emergencyMessage: EmergencyMessage? = nil
    @Published var emergencyServiceResponse: EmergencyServiceResponse? = nil
    @Published var isMessageSending: Bool = false
    @Published var messageStatus: EmergencyMessagingService.MessageStatus? = nil
    
    // Speech recognition properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // NASA EONET API endpoint (no API key needed)
    private let baseURL = "https://eonet.gsfc.nasa.gov/api/v3"
    
    // For tracking processed updates
    private var processedEventIds = Set<String>()
    
    // Cancellables set for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSpeechRecognizer()
        setupSubscriptions()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }
    
    private func setupSubscriptions() {
        // Subscribe to emergency message status updates
        EmergencyMessagingService.shared.messageSendingStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.messageStatus = status
                
                switch status {
                case .preparing, .sending:
                    self?.isMessageSending = true
                case .delivered, .failed:
                    self?.isMessageSending = false
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func fetchInitialData() {
        Task {
            await fetchActiveCrises()
            await generateRecentUpdates()
        }
    }
    
    func fetchActiveCrises() async {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        let endpoint = "/events?status=open&days=30&limit=20"
        
        do {
            guard let url = URL(string: baseURL + endpoint) else {
                throw NSError(domain: "InvalidURL", code: -1, userInfo: nil)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "InvalidResponse", code: -2, userInfo: nil)
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                let decoder = JSONDecoder()
                let eonetResponse = try decoder.decode(EONETResponse.self, from: data)
                
                // Map NASA EONET events to our Crisis model
                let crises = mapEONETEventsToCrises(eonetResponse.events)
                
                DispatchQueue.main.async {
                    self.activeCrises = crises
                    self.isLoading = false
                }
            } else {
                throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil)
            }
        } catch {
            handleError(error: error)
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    private func mapEONETEventsToCrises(_ events: [EONETEvent]) -> [Crisis] {
        return events.compactMap { event in
            guard let latestGeometry = event.geometry.first,
                  latestGeometry.coordinates.count >= 2 else {
                return nil
            }
            
            // Get coordinates (note: EONET uses [longitude, latitude] format)
            let longitude = latestGeometry.coordinates[0]
            let latitude = latestGeometry.coordinates[1]
            
            // Get event category for severity estimation
            let categoryTitle = event.categories.first?.title ?? "Unknown"
            let severity = calculateSeverity(category: categoryTitle, event: event)
            
            // Get approximate location name based on coordinates
            let location = getLocationName(latitude: latitude, longitude: longitude, categoryTitle: categoryTitle)
            
            // Parse date
            let dateFormatter = ISO8601DateFormatter()
            let startDate = dateFormatter.date(from: latestGeometry.date) ?? Date()
            
            // Create description combining event info
            let description = event.description ?? "A \(categoryTitle.lowercased()) event has been reported in this area. Monitor local authorities for more information."
            
            return Crisis(
                id: event.id,
                name: event.title,
                location: location,
                severity: severity,
                startDate: startDate,
                description: description,
                affectedPopulation: estimateAffectedPopulation(category: categoryTitle, coordinates: Coordinates(latitude: latitude, longitude: longitude)),
                coordinatorContact: "info@globalaidconnect.org",
                coordinates: Coordinates(latitude: latitude, longitude: longitude)
            )
        }
    }
    
    private func calculateSeverity(category: String, event: EONETEvent) -> Int {
        // Assign severity based on event category and other factors
        switch category {
        case "Volcanoes", "Severe Storms", "Wildfires" where event.title.contains("Extreme"):
            return 5
        case "Wildfires", "Floods", "Earthquakes":
            return 4
        case "Drought", "Landslides":
            return 3
        case "Sea and Lake Ice", "Snow":
            return 2
        default:
            return 1
        }
    }
    
    private func getLocationName(latitude: Double, longitude: Double, categoryTitle: String) -> String {
        // In a real app, you would use reverse geocoding here
        // For now, we'll just create an approximate location string based on coordinates
        let latDirection = latitude >= 0 ? "N" : "S"
        let longDirection = longitude >= 0 ? "E" : "W"
        let formattedLat = String(format: "%.1f", abs(latitude))
        let formattedLong = String(format: "%.1f", abs(longitude))
        
        // Find continent/region based on coordinates (very simplified)
        let region = getApproximateRegion(latitude: latitude, longitude: longitude)
        
        return "\(region), \(formattedLat)°\(latDirection) \(formattedLong)°\(longDirection)"
    }
    
    private func getApproximateRegion(latitude: Double, longitude: Double) -> String {
        // Extremely simplified region determination
        if latitude > 30 && longitude > -30 && longitude < 60 {
            return "Europe"
        } else if latitude > 10 && longitude > 60 && longitude < 150 {
            return "Asia"
        } else if latitude < 0 && longitude > 110 && longitude < 180 {
            return "Australia"
        } else if latitude > 10 && longitude > -150 && longitude < -50 {
            return "North America"
        } else if latitude < 10 && latitude > -60 && longitude > -90 && longitude < -30 {
            return "South America"
        } else if latitude < 40 && latitude > -40 && longitude > -20 && longitude < 60 {
            return "Africa"
        } else {
            return "Ocean Region"
        }
    }
    
    private func estimateAffectedPopulation(category: String, coordinates: Coordinates) -> Int {
        // This would ideally use population density data
        // For now, use a simple estimation based on category and random variance
        
        let basePeople: Int
        switch category {
        case "Wildfires":
            basePeople = 5000 + Int.random(in: 0...10000)
        case "Volcanoes":
            basePeople = 15000 + Int.random(in: 0...50000)
        case "Severe Storms", "Floods":
            basePeople = 25000 + Int.random(in: 0...75000)
        case "Earthquakes":
            basePeople = 30000 + Int.random(in: 0...100000)
        case "Drought":
            basePeople = 50000 + Int.random(in: 0...150000)
        default:
            basePeople = 1000 + Int.random(in: 0...5000)
        }
        
        return basePeople
    }
    
    // Generate updates based on active crises
    func generateRecentUpdates() async {
        guard let crises = activeCrises, !crises.isEmpty else {
            // If no crises available, wait for them to load first
            if activeCrises == nil {
                await fetchActiveCrises()
                if let loadedCrises = activeCrises, !loadedCrises.isEmpty {
                    await generateRecentUpdatesFromCrises(loadedCrises)
                }
            }
            return
        }
        
        await generateRecentUpdatesFromCrises(crises)
    }
    
    private func generateRecentUpdatesFromCrises(_ crises: [Crisis]) async {
        // Get the 5 most recent crises based on startDate
        let recentCrises = Array(crises.sorted(by: { $0.startDate > $1.startDate }).prefix(5))
        
        var updates: [Update] = []
        
        for (index, crisis) in recentCrises.enumerated() {
            // Create 1-2 updates per crisis
            let updateCount = index < 2 ? 2 : 1
            
            for i in 0..<updateCount {
                let hoursAgo = Double(i * 4 + Int.random(in: 1...3))
                let timestamp = Date().addingTimeInterval(-3600 * hoursAgo)
                
                updates.append(Update(
                    id: "u\(UUID().uuidString.prefix(8))",
                    crisisId: crisis.id,
                    title: generateUpdateTitle(for: crisis, updateNumber: i),
                    content: generateUpdateContent(for: crisis, updateNumber: i),
                    timestamp: timestamp,
                    source: generateSource(for: crisis)
                ))
            }
        }
        
        // Sort by timestamp (most recent first)
        let sortedUpdates = updates.sorted(by: { $0.timestamp > $1.timestamp })
        
        DispatchQueue.main.async {
            self.recentUpdates = sortedUpdates
        }
    }
    
    private func generateUpdateTitle(for crisis: Crisis, updateNumber: Int) -> String {
        let titles = [
            ["Initial Assessment", "Situation Report", "Emergency Declaration"],
            ["Response Underway", "Aid Deployment", "Rescue Operations"],
            ["Status Update", "Situation Developing", "Continued Monitoring"]
        ]
        
        if updateNumber < titles.count {
            return titles[updateNumber][Int.random(in: 0..<titles[updateNumber].count)]
        } else {
            return "Ongoing Response"
        }
    }
    
    private func generateUpdateContent(for crisis: Crisis, updateNumber: Int) -> String {
        switch updateNumber {
        case 0:
            return "Initial assessment of the \(crisis.name.lowercased()) shows affected area of approximately \(Int.random(in: 5...50)) square kilometers. Local authorities are coordinating emergency response."
        case 1:
            return "Relief supplies being deployed to \(crisis.location). \(Int.random(in: 3...20)) emergency response teams active in the area. Local shelters established for displaced residents."
        default:
            return "Ongoing monitoring of \(crisis.name.lowercased()) continues. Weather conditions \(["improving", "stable", "worsening"][Int.random(in: 0...2)]) which may affect response efforts."
        }
    }
    
    private func generateSource(for crisis: Crisis) -> String {
        let sources = [
            "Emergency Response Team",
            "Global Aid Network",
            "Regional Coordination Center",
            "Humanitarian Aid Coalition",
            "Disaster Assessment Unit"
        ]
        
        return sources[Int.random(in: 0..<sources.count)]
    }
    
    // MARK: - Emergency Reporting Methods
    
    func submitEmergencyReport(message: String, location: CLLocationCoordinate2D?) async -> Bool {
        DispatchQueue.main.async {
            self.isProcessingEmergency = true
            self.currentEmergency = EmergencyReport(
                message: message,
                location: location,
                severity: nil,
                category: nil,
                isProcessed: false
            )
        }
        
        // First, analyze the emergency situation using AI
        if let analysis = await analyzeEmergencySituation(
            inputText: message,
            location: location,
            useClaudeAI: true
        ) {
            // Create an AI-based emergency analysis response
            let analysisResponse = EmergencyAnalysisResponse(
                severity: analysis.severity,
                category: analysis.type,
                urgency: analysis.urgency.description,
                recommendedActions: analysis.recommendedActions,
                estimatedAffectedArea: analysis.affectedArea?.radius
            )
            
            DispatchQueue.main.async {
                self.emergencyAnalysis = analysisResponse
                self.situationAnalysis = analysis // Store the full analysis
            }
            
            // Create and send the emergency message
            let emergencyMessage = await prepareEmergencyMessage(
                analysis: analysis,
                message: message,
                location: location
            )
            
            // Send the message to emergency services
            let serviceResponse = await sendEmergencyMessageToServices(emergencyMessage)
            
            DispatchQueue.main.async {
                self.isProcessingEmergency = false
            }
            
            return serviceResponse != nil
            
        } else {
            // If AI analysis fails, create a simple fallback response
            let fallbackResponse = EmergencyAnalysisResponse(
                severity: 3,
                category: "Unspecified Emergency",
                urgency: "Response Required Soon",
                recommendedActions: [
                    "Contact local emergency services",
                    "Follow safety protocols",
                    "Stay informed through official channels"
                ],
                estimatedAffectedArea: 1.0
            )
            
            DispatchQueue.main.async {
                self.emergencyAnalysis = fallbackResponse
                self.isProcessingEmergency = false
            }
            
            // Create a basic emergency message without detailed analysis
            let emergencyMessage = await prepareEmergencyMessage(
                analysis: nil,
                message: message,
                location: location
            )
            
            // Send the message to emergency services
            let serviceResponse = await sendEmergencyMessageToServices(emergencyMessage)
            
            return serviceResponse != nil
        }
    }
    
    // MARK: - Emergency Messaging Methods
    
    /// Prepares an emergency message based on AI analysis and user input
    func prepareEmergencyMessage(
        analysis: SituationAnalysis?,
        message: String,
        location: CLLocationCoordinate2D?
    ) async -> EmergencyMessage {
        // Create an emergency report from the input
        let report = EmergencyReport(
            message: message,
            location: location,
            severity: analysis?.severity,
            category: analysis?.type,
            isProcessed: false
        )
        
        // Convert coordinates to CLLocation for better handling
        let clLocation: CLLocation?
        if let location = location {
            clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        } else {
            clLocation = nil
        }
        
        // Use the EmergencyMessagingService to create a formatted message
        let emergencyMessage = EmergencyMessagingService.shared.createEmergencyMessage(
            from: analysis,
            report: report,
            location: clLocation
        )
        
        // Store the message for reference
        DispatchQueue.main.async {
            self.emergencyMessage = emergencyMessage
        }
        
        return emergencyMessage
    }
    
    /// Sends an emergency message to emergency services
    func sendEmergencyMessageToServices(_ message: EmergencyMessage) async -> EmergencyServiceResponse? {
        // Use the EmergencyMessagingService to send the message
        let result = await EmergencyMessagingService.shared.simulateSendEmergencyMessage(message)
        
        switch result {
        case .success(let response):
            DispatchQueue.main.async {
                self.emergencyServiceResponse = response
            }
            return response
            
        case .failure(let error):
            DispatchQueue.main.async {
                self.emergencyError = "Failed to contact emergency services: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    // MARK: - Speech Recognition Methods
    
    func requestSpeechRecognitionPermission() async -> Bool {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return false
        }
        
        var isAuthorized = false
        
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            isAuthorized = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { authStatus in
                    continuation.resume(returning: authStatus == .authorized)
                }
            }
        } else {
            isAuthorized = (status == .authorized)
        }
        
        return isAuthorized
    }
    
    func startSpeechRecognition() {
        // Stop any ongoing recognition
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Set up the audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error)")
            return
        }
        
        // Set up recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create a speech recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Set up recognition task
        guard let speechRecognizer = speechRecognizer else {
            print("Speech recognizer not available")
            return
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                // Update the recognized text
                DispatchQueue.main.async {
                    self.recognizedSpeech = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                // Stop audio engine
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isRecognizingSpeech = false
                }
            }
        }
        
        // Set up audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isRecognizingSpeech = true
            }
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }
    
    func stopSpeechRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        
        audioEngine.inputNode.removeTap(onBus: 0)
        
        DispatchQueue.main.async {
            self.isRecognizingSpeech = false
        }
    }
    
    // MARK: - Private Methods
    
    private func performRequest<T: Decodable>(endpoint: String, resultType: T.Type, completion: @escaping (Result<T, Error>) -> Void) async {
        guard let url = URL(string: baseURL + endpoint) else {
            completion(.failure(NSError(domain: "InvalidURL", code: -1, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "InvalidResponse", code: -2, userInfo: nil)))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let decodedData = try decoder.decode(T.self, from: data)
                    completion(.success(decodedData))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil)))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private func handleError(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error.localizedDescription
            print("API Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - AI Service Extension
extension ApiService {
    // Claude API endpoints and keys - Use real production endpoints
    private var claudeApiUrl: String { "https://api.anthropic.com/v1/messages" }
    private var claudeApiKey: String { "YOUR_CLAUDE_API_KEY" } // Replace with your key for production
    private var claudeApiVersion: String { "2023-06-01" }
    
    // GPT API endpoints and keys - Use real production endpoints
    private var gptApiUrl: String { "https://api.openai.com/v1/chat/completions" }
    private var gptApiKey: String { "YOUR_GPT_API_KEY" } // Replace with your key for production
    
    // MARK: - Situation Analysis Methods
    
    /// Analyzes emergency situation details using AI
    func analyzeEmergencySituation(
        inputText: String,
        location: CLLocationCoordinate2D? = nil,
        useClaudeAI: Bool = true
    ) async -> SituationAnalysis? {
        
        DispatchQueue.main.async {
            self.isProcessingSituation = true
            self.situationError = nil
        }
        
        // Create location context if available
        let locationContext: String
        if let location = location {
            locationContext = "The user's current coordinates are: Latitude \(location.latitude), Longitude \(location.longitude)."
        } else {
            locationContext = "The user's current location is unknown."
        }
        
        // Create system prompt for structured analysis
        let systemPrompt = """
        You are an emergency response AI trained to analyze emergency situations and provide structured assessments.
        Given a description of an emergency situation, analyze it and provide a detailed assessment in JSON format.
        
        Consider the following in your analysis:
        1. The urgency level of the situation (immediate, urgent, moderate, or low)
        2. The type/category of emergency (medical, natural disaster, fire, etc.)
        3. The severity on a scale of 1-5 (5 being most severe)
        4. Any location hints from the message that could help responders
        5. Recommended immediate actions
        6. Potential risks or complications
        7. Estimate of affected area (if applicable)
        
        \(locationContext)
        
        Respond ONLY with a JSON object in the following format:
        {
          "urgency": "immediate|urgent|moderate|low",
          "type": "string",
          "severity": integer,
          "locationHints": ["string"],
          "recommendedActions": ["string"],
          "potentialRisks": ["string"],
          "affectedArea": {
            "radius": double,
            "estimatedPopulation": integer,
            "terrainType": "string"
          },
          "timestamp": "ISO-8601 date string"
        }
        
        Ensure your analysis is based solely on the provided information. Do not make up details, but infer reasonable information where appropriate. If certain fields cannot be determined, use null for those values or omit optional fields.
        """
        
        do {
            let result: String?
            
            if useClaudeAI {
                // Use Claude
                let messages: [AIMessage] = [
                    AIMessage(role: "system", content: systemPrompt),
                    AIMessage(role: "user", content: inputText)
                ]
                
                let claudeRequest = ClaudeRequest(
                    model: "claude-3-sonnet-20240229",
                    messages: messages,
                    temperature: 0.2, // Low temperature for more consistent results
                    maxTokens: 2000
                )
                
                result = await sendStructuredRequestToClaude(request: claudeRequest)
                
            } else {
                // Use GPT
                let messages: [AIMessage] = [
                    AIMessage(role: "system", content: systemPrompt),
                    AIMessage(role: "user", content: inputText)
                ]
                
                let gptRequest = GPTRequest(
                    model: "gpt-4",
                    messages: messages,
                    temperature: 0.2, // Low temperature for more consistent results
                    maxTokens: 2000,
                    responseFormat: ResponseFormat(type: "json_object")
                )
                
                result = await sendStructuredRequestToGPT(request: gptRequest)
            }
            
            // Parse the JSON response
            if let jsonString = result {
                // Extract JSON if embedded in markdown code blocks
                let cleanedJson = extractJsonFromString(jsonString)
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                if let jsonData = cleanedJson.data(using: .utf8) {
                    let analysis = try decoder.decode(SituationAnalysis.self, from: jsonData)
                    
                    DispatchQueue.main.async {
                        self.situationAnalysis = analysis
                        self.isProcessingSituation = false
                    }
                    
                    return analysis
                } else {
                    throw NSError(domain: "JSONParsingError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to data"])
                }
            } else {
                throw NSError(domain: "AIResponseError", code: -4, userInfo: [NSLocalizedDescriptionKey: "No response from AI service"])
            }
            
        } catch {
            DispatchQueue.main.async {
                self.situationError = "Error analyzing emergency situation: \(error.localizedDescription)"
                self.isProcessingSituation = false
            }
            print("Situation Analysis Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Sends a structured request to Claude AI expecting JSON response
    private func sendStructuredRequestToClaude(request: ClaudeRequest) async -> String? {
        do {
            let jsonData = try JSONEncoder().encode(request)
            
            // Create the request
            var apiRequest = URLRequest(url: URL(string: claudeApiUrl)!)
            apiRequest.httpMethod = "POST"
            apiRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            apiRequest.addValue("anthropic-version: \(claudeApiVersion)", forHTTPHeaderField: "x-api-version")
            apiRequest.addValue("Bearer \(claudeApiKey)", forHTTPHeaderField: "Authorization")
            apiRequest.httpBody = jsonData
            
            // Send the request
            let (data, response) = try await URLSession.shared.data(for: apiRequest)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
            }
            
            // Parse the response
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(AIResponse.self, from: data)
            
            if let choice = apiResponse.choices.first {
                return choice.message.content
            }
            
            return nil
        } catch {
            print("Claude API Error: \(error)")
            return nil
        }
    }
    
    /// Sends a structured request to GPT AI expecting JSON response
    private func sendStructuredRequestToGPT(request: GPTRequest) async -> String? {
        do {
            let jsonData = try JSONEncoder().encode(request)
            
            // Create the request
            var apiRequest = URLRequest(url: URL(string: gptApiUrl)!)
            apiRequest.httpMethod = "POST"
            apiRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            apiRequest.addValue("Bearer \(gptApiKey)", forHTTPHeaderField: "Authorization")
            apiRequest.httpBody = jsonData
            
            // Send the request
            let (data, response) = try await URLSession.shared.data(for: apiRequest)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
            }
            
            // Parse the response
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(AIResponse.self, from: data)
            
            if let choice = apiResponse.choices.first {
                return choice.message.content
            }
            
            return nil
        } catch {
            print("GPT API Error: \(error)")
            return nil
        }
    }
    
    /// Extract JSON object from a string that might contain markdown formatting
    private func extractJsonFromString(_ input: String) -> String {
        // Check if the response is wrapped in code blocks
        if input.contains("```json") && input.contains("```") {
            let pattern = "```json\\s*(.+?)\\s*```"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
                if let match = regex.firstMatch(in: input, options: [], range: nsRange) {
                    let matchRange = match.range(at: 1)
                    if let range = Range(matchRange, in: input) {
                        return String(input[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        
        // If no code blocks, just look for JSON object pattern
        if input.trimmingCharacters(in: .whitespacesAndNewlines).starts(with: "{") {
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return input
    }
    
    // MARK: - Public AI Methods
    
    /// Sends a message to Claude AI
    func sendMessageToClaude(userMessage: String) async -> String? {
        // Add user message to conversation, but ensure we have a system message first
        ensureSystemPromptExists()
        
        let newUserMessage = AIMessage(role: "user", content: userMessage)
        DispatchQueue.main.async {
            self.currentConversation.append(newUserMessage)
            self.isProcessingAI = true
        }
        
        // Create the request body
        let requestBody = ClaudeRequest(
            model: "claude-3-sonnet-20240229",
            messages: self.currentConversation,
            temperature: 0.7,
            maxTokens: 1000
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            
            // Create the request
            var request = URLRequest(url: URL(string: claudeApiUrl)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("anthropic-version: \(claudeApiVersion)", forHTTPHeaderField: "x-api-version")
            request.addValue("Bearer \(claudeApiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            
            // Send the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
            }
            
            // Parse the response
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(AIResponse.self, from: data)
            
            if let choice = apiResponse.choices.first {
                let assistantMessage = choice.message
                
                // Update conversation on main thread
                DispatchQueue.main.async {
                    self.currentConversation.append(assistantMessage)
                    self.isProcessingAI = false
                }
                
                return assistantMessage.content
            }
            
            return nil
        } catch {
            // Handle errors
            DispatchQueue.main.async {
                self.aiErrorMessage = "Error communicating with Claude: \(error.localizedDescription)"
                self.isProcessingAI = false
            }
            print("Claude API Error: \(error)")
            return nil
        }
    }
    
    /// Sends a message to GPT AI
    func sendMessageToGPT(userMessage: String) async -> String? {
        // Add user message to conversation, but ensure we have a system message first
        ensureSystemPromptExists()
        
        let newUserMessage = AIMessage(role: "user", content: userMessage)
        DispatchQueue.main.async {
            self.currentConversation.append(newUserMessage)
            self.isProcessingAI = true
        }
        
        // Create the request body
        let requestBody = GPTRequest(
            model: "gpt-4",
            messages: self.currentConversation,
            temperature: 0.7,
            maxTokens: 1000,
            responseFormat: nil
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            
            // Create the request
            var request = URLRequest(url: URL(string: gptApiUrl)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("Bearer \(gptApiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            
            // Send the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check response status
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil)
            }
            
            // Parse the response
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(AIResponse.self, from: data)
            
            if let choice = apiResponse.choices.first {
                let assistantMessage = choice.message
                
                // Update conversation on main thread
                DispatchQueue.main.async {
                    self.currentConversation.append(assistantMessage)
                    self.isProcessingAI = false
                }
                
                return assistantMessage.content
            }
            
            return nil
        } catch {
            // Handle errors
            DispatchQueue.main.async {
                self.aiErrorMessage = "Error communicating with GPT: \(error.localizedDescription)"
                self.isProcessingAI = false
            }
            print("GPT API Error: \(error)")
            return nil
        }
    }
    
    /// Ensures that the conversation starts with a system message
    private func ensureSystemPromptExists() {
        // Only add system message if the conversation doesn't already have one
        if currentConversation.isEmpty || !currentConversation.contains(where: { $0.role == "system" }) {
            // Create emergency response system prompt
            let systemPrompt = """
            You are an emergency response AI assistant in the Global Aid Connect app. Your primary role is to:
            
            1. Help users assess emergency situations and provide guidance
            2. Offer practical advice during crisis scenarios
            3. Help users understand disaster preparedness
            4. Provide information on how to contact local emergency services
            
            When users ask questions, provide calm, clear, and concise information focused on safety and appropriate response actions. If the user appears to be in an immediate emergency, emphasize that they should contact official emergency services (like 911 in the US) while also providing helpful guidance.
            
            Always be compassionate, take emergencies seriously, but remain factual and avoid creating unnecessary panic. When appropriate, direct users to use the app's emergency reporting features.
            """
            
            let systemMessage = AIMessage(role: "system", content: systemPrompt)
            
            // Insert at the beginning of conversation
            DispatchQueue.main.async {
                self.currentConversation.insert(systemMessage, at: 0)
            }
        }
    }
    
    /// Process voice input and convert to text using on-device speech recognition
    func processVoiceToText(audioData: Data) async -> String? {
        // Since we cannot use a real speech-to-text API in this example,
        // we'll use a fallback simulated response to demonstrate the flow
        
        do {
            // In a real app, you would send the audioData to a service
            // For now, we'll simulate a successful transcription
            return "This is a simulated transcription of the audio recording for emergency reporting purposes."
        } catch {
            print("Voice transcription error: \(error)")
            return nil
        }
    }
    
    /// Clears the current conversation
    func clearConversation() {
        currentConversation = []
    }
    
    // MARK: - Emergency Messaging Service
    // Add this code at the end of your ApiService.swift file
    
    /// Struct for holding user information in emergency messages
    
    
    /// App information to include with emergency messages
    struct AppInfo: Codable {
        let appId: String
        let version: String
        let platform: String
        
        init(appId: String = "com.globalaidconnect.app",
             version: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
             platform: String = "iOS") {
            self.appId = appId
            self.version = version
            self.platform = platform
        }
    }
    
    /// Service for creating and sending emergency messages
    // MARK: - Emergency Messaging Service
    // Add this code at the end of your ApiService.swift file
    
    /// Service for creating and sending emergency messages
    class EmergencyMessagingService {
        static let shared = EmergencyMessagingService()
        
        // Status publisher
        private let messageStatusSubject = PassthroughSubject<MessageStatus, Never>()
        var messageSendingStatus: AnyPublisher<MessageStatus, Never> {
            messageStatusSubject.eraseToAnyPublisher()
        }
        
        // Message status enum
        enum MessageStatus {
            case preparing
            case sending
            case delivered(messageId: String, timestamp: Date)
            case failed(error: Error)
        }
        
        // Private properties
        private var timer: Timer?
        private var currentlyProcessingMessage: EmergencyMessage?
        
        private init() {}
        
        /// Creates a formatted emergency message based on analysis and user report
        func createEmergencyMessage(
            from analysis: SituationAnalysis?,
            report: EmergencyReport,
            location: CLLocation?
        ) -> EmergencyMessage {
            
            // Publish preparing status
            messageStatusSubject.send(.preparing)
            
            // Prepare location data
            let locationData = LocationData(
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                address: nil,
                regionName: extractRegionFromCoordinates(location?.coordinate)
            )
            
            // Create user info (in a real app, this would come from saved profile)
            let userInfo = UserInfo(
                id: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            )
            
            // Determine emergency type and severity from analysis or fallback to defaults
            let emergencyType = analysis?.type ?? "Unspecified Emergency"
            let urgency = analysis?.urgency.rawValue ?? "moderate"
            let severity = analysis?.severity ?? 3
            
            // Extract recommended actions
            let actions = analysis?.recommendedActions ?? [
                "Contact local emergency services",
                "Follow safety protocols",
                "Stay informed through official channels"
            ]
            
            // Create the emergency message
            let message = EmergencyMessage(
                emergencyType: emergencyType,
                urgency: urgency,
                severity: severity,
                description: report.message,
                location: locationData,
                userInfo: userInfo,
                actions: actions
            )
            
            return message
        }
        
        /// Simulates sending an emergency message to services
        func simulateSendEmergencyMessage(_ message: EmergencyMessage) async -> Result<EmergencyServiceResponse, Error> {
            // Update status
            self.currentlyProcessingMessage = message
            messageStatusSubject.send(.sending)
            
            // Simulate network delay
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            // Simulate success (90% of the time)
            if Double.random(in: 0...1) < 0.9 {
                // Generate a response
                let response = EmergencyServiceResponse(
                    success: true,
                    messageId: "ER-\(Int.random(in: 100000...999999))",
                    responseCode: "MSG_RECEIVED",
                    estimatedResponseTime: Int.random(in: 5...20),
                    message: "Your emergency has been received and responders have been notified.",
                    actions: [
                        "Stay in a safe location",
                        "Keep your phone accessible",
                        "Responders will contact you shortly"
                    ]
                )
                
                // Publish delivered status
                messageStatusSubject.send(.delivered(messageId: response.messageId, timestamp: Date()))
                
                return .success(response)
            } else {
                // Simulate failure
                let error = NSError(
                    domain: "EmergencyMessaging",
                    code: 408,
                    userInfo: [NSLocalizedDescriptionKey: "Connection timeout. Emergency services could not be reached."]
                )
                
                // Publish failure status
                messageStatusSubject.send(.failed(error: error))
                
                return .failure(error)
            }
        }
        
        // MARK: - Helper Methods
        
        /// Extracts region name from coordinates
        private func extractRegionFromCoordinates(_ coordinates: CLLocationCoordinate2D?) -> String? {
            guard let coordinates = coordinates else {
                return nil
            }
            
            // In a real app, this would use reverse geocoding
            // For this demo, we'll use a simplified approach based on coordinates
            
            // Example implementation
            if coordinates.latitude > 30 && coordinates.longitude > -30 && coordinates.longitude < 60 {
                return "Europe"
            } else if coordinates.latitude > 10 && coordinates.longitude > 60 && coordinates.longitude < 150 {
                return "Asia"
            } else if coordinates.latitude < 0 && coordinates.longitude > 110 && coordinates.longitude < 180 {
                return "Australia"
            } else if coordinates.latitude > 10 && coordinates.longitude > -150 && coordinates.longitude < -50 {
                return "North America"
            } else if coordinates.latitude < 10 && coordinates.latitude > -60 && coordinates.longitude > -90 && coordinates.longitude < -30 {
                return "South America"
            } else if coordinates.latitude < 40 && coordinates.latitude > -40 && coordinates.longitude > -20 && coordinates.longitude < 60 {
                return "Africa"
            } else {
                return "Unknown Region"
            }
        }
    }
    
    
}
