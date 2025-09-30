# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GoTravel is a SwiftUI-based iOS travel planning app that allows users to manage travel plans and track visited places. The app uses Firebase for authentication and data persistence.

## Build and Test Commands

### Building the App
```bash
# Build for simulator (iPhone 15 Pro example)
xcodebuild -project GoTravel.xcodeproj -scheme GoTravel -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Build for device
xcodebuild -project GoTravel.xcodeproj -scheme GoTravel -sdk iphoneos build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -project GoTravel.xcodeproj -scheme GoTravel -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run specific test target
xcodebuild test -project GoTravel.xcodeproj -scheme GoTravel -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:GoTravelTests
xcodebuild test -project GoTravel.xcodeproj -scheme GoTravel -destination 'platform=iOS Simulator,name=iPhone 15 Pro' -only-testing:GoTravelUITests
```

### Opening in Xcode
```bash
open GoTravel.xcodeproj
```

## Architecture

### App Structure
The app follows an MVVM (Model-View-ViewModel) architecture with SwiftUI views:

- **App Entry**: `GoTravelApp.swift` initializes Firebase and injects `AuthViewModel` as an environment object
- **Root View**: `ContentView.swift` switches between `LoginView` and `MainTabView` based on authentication state
- **Main Navigation**: `MainTabView.swift` provides a 4-tab interface:
  - 予定 (Plans) - `PlansListView`
  - マップ (Map) - `MapHomeView`
  - 保存済み (Saved Places) - `PlacesListView`
  - マイページ (Profile) - `HomeView`

### Data Layer

The app uses a dual storage strategy:

1. **Plans**: Stored locally in `UserDefaults` via `PlansViewModel`
   - Uses JSON encoding/decoding
   - Stored under key `"plans_v1"`
   - Managed entirely client-side

2. **Visited Places**: Stored in Firebase Firestore via `FirestoreService`
   - Real-time listener setup with `observePlaces()`
   - Per-user collection structure: `users/{uid}/places`
   - Images stored locally in app Documents directory with filenames tracked in Firestore

### Firebase Integration

- **Authentication**: `AuthViewModel` handles sign in/up, sign out, and password reset
  - Uses Firebase Auth state listener for automatic session management
  - Injected as `@EnvironmentObject` throughout the app

- **Firestore**: `FirestoreService` is a singleton managing all database operations
  - Persistent cache enabled for offline support
  - Real-time listeners for automatic UI updates
  - User-scoped data collections

### Key Models

- **VisitedPlace** (`Entites/VisitedPlace.swift`): Represents a saved location
  - Contains coordinates, title, notes, photos, tags, and timestamps
  - Supports both remote (Firestore) and local photo storage

- **Plan** (`PlansList/Plan.swift`): Represents a travel plan
  - Contains title, date range, list of `PlannedPlace` objects, and optional card color
  - Custom Codable implementation for Color serialization (hex conversion)

- **PlannedPlace** (`PlansList/PlannedPlace.swift`): A location within a plan
  - Lightweight model with name, coordinates, and address

### Module Organization

- **App/**: App initialization and configuration
- **Entites/**: Core models and services (`AuthViewModel`, `FirestoreService`, `VisitedPlace`)
- **Login/, SignUp/**: Authentication UI
- **PlansList/**: Travel plan management
  - `Views/`: Subviews for plan display (`EventList`, `TravelCardViews`, `horizontalEventsCard`)
- **PlaceList/**: Visited places list and detail views
- **SavePlace/**: Add/edit visited places
- **Map/**: Map views and location picking
- **Profile/**: User profile and settings
- **GoTravelTests/, GoTravelUITests/**: Test targets

### Image Handling

Images are managed through a custom `FileManager` extension:
- `saveImageDataToDocuments(data:named:)`: Save image to app Documents directory
- `documentsImage(named:)`: Retrieve image from Documents directory
- `removeDocumentFile(named:)`: Delete image file
- Filenames are stored in Firestore but actual image data is local

## Important Notes

- **Firebase Configuration**: `GoogleService-Info.plist` must be present in the `GoTravel/` directory
- **Authentication Required**: Most features require user authentication; `AuthViewModel` manages this globally
- **Coordinate Systems**: Uses `CLLocationCoordinate2D` from CoreLocation for all location data
- **Japanese UI**: The app interface is primarily in Japanese