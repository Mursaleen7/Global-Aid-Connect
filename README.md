# Global Aid Connect

**Global Aid Connect** is an iOS application that enables real-time monitoring of natural disasters, streamlined emergency reporting, AI-powered situation analysis, and simulated dispatch notifications to crisis response teams.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Setup & Installation](#setup--installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Testing](#testing)
- [Folder Structure](#folder-structure)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

## Features

- **Real‑time Crisis Data**: Fetches open events from NASA’s EONET API.
- **Interactive Map**: SwiftUI + MapKit view with annotations for active crises.
- **Updates List**: Browse recent alerts and event details.
- **Speech‑to‑Text Reporting**: AVFoundation & Speech framework integration.
- **AI Situation Analysis**: Uses Anthropic Claude or OpenAI GPT to assess severity, urgency, and recommend actions.
- **Emergency Messaging Simulation**: Simulate message dispatch and track status (sending, delivered, failed).
- **Dark & Light Modes**: Adaptive UI styling.

## Architecture

- **SwiftUI**: Declarative UI components.
- **Combine & Async/Await**: Reactive streams and concurrency for networking.
- **CoreLocation & MapKit**: Geolocation and map rendering.
- **AVFoundation & Speech**: Audio capture and transcription pipelines.
- **URLSession & Codable**: Structured JSON models for API integration.
- **ObservableObject**: `ApiService` manages state and publishes updates to views.

## Prerequisites

- **macOS 12.0+** with **Xcode 14+**
- **iOS 15.0+** deployment target
- **Internet connection**
- **(Optional)** AI service API keys:
  - `ANTHROPIC_API_KEY` for Anthropic Claude
  - `OPENAI_API_KEY` for OpenAI GPT

## Setup & Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Global-Aid-Connect.git
   cd Global-Aid-Connect
   ```
2. **Unzip Xcode project**
   ```bash
   unzip GlobalAidConnect.xcodeproj.zip
   ```
3. **Open in Xcode**
   ```bash
   open GlobalAidConnect.xcodeproj
   ```
4. **Configure API Keys**
   - In Xcode, select **Product → Scheme → Edit Scheme…**
   - Under **Run**, add environment variables:
     - `ANTHROPIC_API_KEY` = _your Claude API key_
     - `OPENAI_API_KEY` = _your OpenAI API key_
5. **Build & Run**
   - Choose a simulator or device
   - Press `⌘R`

## Usage

1. **Launch App** – Automatically retrieves and displays open events from NASA EONET.
2. **Explore Map** – Pan/zoom to view crisis locations.
3. **View Updates** – Tap **Updates** or swipe up for recent alerts.
4. **Report Emergency**
   - Tap the microphone icon to speak, or type your message.
   - Review AI analysis: severity, urgency, recommended actions.
   - Tap **Send** to simulate dispatch to emergency services.
5. **Monitor Status** – Watch real‑time status updates: *Sending*, *Delivered*, or *Failed*.

## Configuration

- **API Endpoint**: Adjust `baseURL` and paths in `ApiService.swift`.
- **Speech Recognition**: Tweak settings in `ApiService`'s speech methods.

## Testing

- Add unit tests under `GlobalAidConnectTests/`.
- Run tests in Xcode with `⌘U`.

## Folder Structure

```
GlobalAidConnect/
├── ApiService.swift          # Networking & AI integration
├── ContentView.swift         # Root navigation and layout
├── HomeView.swift            # Dashboard with map & updates list
├── MapContainerView.swift    # Map view and crisis annotations
├── EvacuationMapView.swift   # (Future) evacuation route visualizer
├── GlobalAidConnectApp.swift # App entry point
├── Item.swift                # Data models for list items
├── Assets.xcassets           # Image and color assets
└── Preview Content/          # SwiftUI previews helpers
```

## Contributing

1. Fork the repo
2. Create branch: `git checkout -b feature/YourFeature`
3. Commit: `git commit -m "Add feature description"`
4. Push: `git push origin feature/YourFeature`
5. Open a pull request.

Please follow Swift style guidelines and include tests for new functionality.

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

## Acknowledgements

- **NASA EONET API** for live disaster data
- **Anthropic Claude** & **OpenAI GPT** for AI-driven analysis
- **Apple** frameworks: SwiftUI, Combine, AVFoundation, CoreLocation
- Inspired by global humanitarian and crisis response initiatives
