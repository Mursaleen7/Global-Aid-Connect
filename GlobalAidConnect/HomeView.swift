import SwiftUI
import Combine
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var apiService: ApiService
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                headerSection
                
                // Active crises section
                if isLoading {
                    loadingView
                } else if let crises = apiService.activeCrises, !crises.isEmpty {
                    activeCrisesSection(crises: crises)
                } else {
                    emptyStateView
                }
                
                // Recent updates section
                if let updates = apiService.recentUpdates, !updates.isEmpty {
                    recentUpdatesSection(updates: updates)
                }
            }
            .padding()
        }
        .refreshable {
            // Pull to refresh functionality
            await refreshData()
        }
        .onAppear {
            Task {
                await refreshData()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Global Aid Connect")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Connecting aid where it's needed most")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 8)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("Loading crisis data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("No active crises")
                .font(.headline)
            
            Text("There are currently no active crises requiring immediate attention.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func activeCrisesSection(crises: [Crisis]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Crises")
                .font(.headline)
            
            ForEach(crises) { crisis in
                NavigationLink(destination: CrisisDetailView(crisis: crisis)) {
                    CrisisCardView(crisis: crisis)
                }
            }
        }
    }
    
    private func recentUpdatesSection(updates: [Update]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Updates")
                .font(.headline)
            
            ForEach(updates) { update in
                UpdateCardView(update: update)
            }
        }
    }
    
    // MARK: - Data Methods
    
    private func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Call the actual API methods
        await apiService.fetchActiveCrises()
        await apiService.generateRecentUpdates()
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView()
                .environmentObject(ApiService())
        }
    }
}

// MARK: - Crisis Detail View
struct CrisisDetailView: View {
    let crisis: Crisis
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text(crisis.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Location & Date
                HStack {
                    Label(crisis.location, systemImage: "mappin.circle.fill")
                    Spacer()
                    Label(formatDate(crisis.startDate), systemImage: "calendar")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                // Severity indicator
                HStack {
                    Text("Severity Level: \(crisis.severity)")
                        .font(.headline)
                    
                    ForEach(1...5, id: \.self) { level in
                        Image(systemName: level <= crisis.severity ? "circle.fill" : "circle")
                            .foregroundColor(level <= crisis.severity ? .red : .gray)
                    }
                }
                .padding(.vertical)
                
                Divider()
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overview")
                        .font(.headline)
                    
                    Text(crisis.description)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Divider()
                
                // Additional stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("Impact")
                        .font(.headline)
                    
                    Label("Affected Population: \(crisis.affectedPopulation.formatted())",
                          systemImage: "person.3.fill")
                }
                
                // Coordinator contact if available
                if let contact = crisis.coordinatorContact {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact")
                            .font(.headline)
                        
                        Label(contact, systemImage: "person.fill.questionmark")
                    }
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Volunteer for This Crisis") {
                        // Action functionality
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Share Information") {
                        // Sharing functionality
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.top)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Crisis Card View
struct CrisisCardView: View {
    let crisis: Crisis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(crisis.name)
                    .font(.headline)
                Spacer()
                severityIndicator
            }
            
            Text(crisis.location)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack {
                Label("\(crisis.affectedPopulation.formatted()) affected",
                      systemImage: "person.3")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(timeAgo(from: crisis.startDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var severityIndicator: some View {
        HStack(spacing: 4) {
            ForEach(1...crisis.severity, id: \.self) { _ in
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var severityColor: Color {
        switch crisis.severity {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        case 2: return .blue
        default: return .green
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Update Card View
struct UpdateCardView: View {
    let update: Update
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(update.title)
                    .font(.headline)
                Spacer()
                Text(formatTime(update.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(update.content)
                .font(.subheadline)
                .lineLimit(2)
            
            HStack {
                Spacer()
                Text("Source: \(update.source)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
