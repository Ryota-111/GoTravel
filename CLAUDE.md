# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GoTravel is a SwiftUI-based iOS travel planning app that allows users to manage travel plans and track visited places. The app uses cloudKit for authentication and data persistence.

## Build and Test Commands

### Building the App
```bash
# Build for simulator (iPhone 17 Pro example)
xcodebuild -project GoTravel.xcodeproj -scheme GoTravel -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

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
MVVM アーキテクチャ（SwiftUI + Core Data）:

- **App Entry** (`App/GoTravelApp.swift`):
  - `CoreDataManager.shared` を初期化（CloudKit 自動同期開始）
  - `AuthViewModel` を `@StateObject` で生成し `@EnvironmentObject` として注入
  - `NotificationService` の通知許可リクエスト
  - ロケールを `ja_JP` に固定

- **起動フロー**:
  1. `SplashScreenView`: スプラッシュ表示 → 初回起動なら `OnboardingView` へ
  2. `OnboardingView`: 機能紹介（4ページ）→ 完了で `ContentView` へ
  3. `ContentView`: `auth.isSignedIn` で `LoginView` / `MainTabView` を切り替え

- **認証** (`ViewModels/AuthViewModel.swift`):
  - Apple Sign In で取得した `userId`・`userFullName`・`userEmail` を `UserDefaults` に永続化
  - 再起動時に `UserDefaults` から復元して自動ログイン状態を維持

- **Main Navigation** (`Views/Contents/MainTabView.swift`): 4タブ構成
  - 計画 — `EnjoyWorldView`（旅行計画 + おでかけ・日常予定）
  - カレンダー — `CalendarView`
  - 場所保存 — `PlacesListView`
  - アルバム — `AlbumHomeView`

### Data Layer

すべてのデータは **Core Data + CloudKit 自動同期** で管理される。

- **永続化**: `NSPersistentCloudKitContainer`（`CoreDataManager.shared`）を使用
  - CloudKit コンテナID: `iCloud.com.gmail.taismryotasis.Travory`
  - `automaticallyMergesChangesFromParent = true` でリモート変更を自動マージ
  - `NSPersistentStoreRemoteChange` 通知でリモート変更を監視

- **Plans** (`PlanEntity`): `PlansViewModel` が `NSFetchedResultsController` で管理
  - ユーザーIDでフィルタリング、開始日降順ソート
  - 保存・更新・削除 → Core Data → CloudKit へ自動同期

- **VisitedPlace** (`VisitedPlaceEntity`): `PlacesViewModel` が同様に管理
  - 訪問日降順ソート
  - 画像データはアプリの Documents ディレクトリにローカル保存、ファイル名のみ Core Data に記録

- **TravelPlan** (`TravelPlanEntity`): `TravelPlanViewModel` が管理
  - 旅行計画（複数日程・スケジュール）を表すエンティティ

- **CloudKitService**: `CKContainer` への直接アクセスが必要な操作（iCloud 利用可否確認など）に使用するシングルトン

- **CloudKitMigrationService**: 旧データからの初回移行処理を担当（初回起動時のみ実行）

### 認証

- **Apple Sign In** (`AppleAuthView`) を使用
  - `ASAuthorizationAppleIDCredential.user` をユーザーIDとして採用
  - `AuthViewModel` が認証状態を管理し、`@EnvironmentObject` としてアプリ全体に注入

### Key Models

- **TravelPlan** (`Models/TravelPlan.swift`): 旅行計画（複数日程）
  - 目的地・日程・`DaySchedule` 配列・持ち物リスト（`PackingItem`）・共有情報を持つ
  - `cardColor` は hex 文字列で Codable シリアライズ
  - 共有機能: `shareCode`・`sharedWith`（ユーザーID配列）・`ownerId`

- **DaySchedule** (`Models/DaySchedule.swift`): TravelPlan 内の1日分スケジュール
  - `dayNumber`（何日目か）と `ScheduleItem` 配列を持つ

- **ScheduleItem** (`Models/ScheduleItem.swift`): スケジュールの1項目
  - 時刻・場所・費用・地図URL・外部リンクを持つ

- **Plan** (`Models/Plan.swift`): おでかけ・日常の予定（軽量）
  - `planType`: `.outing`（おでかけ）/ `.daily`（日常）
  - `scheduleItems`（`PlanScheduleItem` 配列）・`cardColor`（hex Codable）を持つ

- **PlannedPlace** (`Models/PlannedPlace.swift`): Plan 内の訪問予定地
  - 名前・座標・住所の軽量モデル

- **VisitedPlace** (`Models/VisitedPlace.swift`): 訪問済みの場所の記録
  - 座標・タイトル・メモ・カテゴリ・タグ・訪問日・画像ファイル名を持つ
  - `travelPlanId` で TravelPlan と紐付け可能

### Module Organization

- **App/**: アプリ起動・初期化（`GoTravelApp.swift`）
- **Models/**: 全データモデル（`TravelPlan`, `Plan`, `VisitedPlace`, `DaySchedule` など）
- **ViewModels/**: `TravelPlanViewModel`, `PlansViewModel`, `PlacesViewModel`, `AuthViewModel`, `ProfileViewModel`, `SavePlaceViewModel`
- **Services/**: `CloudKitService`, `CloudKitMigrationService`, `WeatherService`, `NotificationService`, `AlbumManager`, `JapanPhotoManager`, `ThemeManager`
- **CoreData/**: `CoreDataManager`, エンティティ拡張（`PlanEntity`, `TravelPlanEntity`, `VisitedPlaceEntity`）
- **Views/Album/**: アルバム機能（`AlbumHomeView`, `AlbumDetailView`, `CreateAlbumView`, `JapanPhotoView`）
- **Views/Authentication/**: Apple Sign In（`AppleAuthView`）
- **Views/Calendar/**: カレンダー表示（`CalendarView`）
- **Views/Contents/**: 共通UI（`MainTabView`, `ContentView`, `SplashScreenView`, `OnboardingView` など）
- **Views/Map/**: マップ（`MapHomeView`, `MapViewRepresentable`, `SearchableMapView`）
- **Views/Places/**: 訪問済み場所（`PlacesListView`, `PlaceDetailView`, `SaveAsVisitedView` など）
- **Views/Plans/**: おでかけ・日常予定（`EnjoyWorldView`, `AddPlanView`, `PlanDetailView` など）
- **Views/Travel/**: 旅行計画（`TravelPlanDetailView`, `AddTravelPlanView`, `ScheduleEditorView` など）
- **Views/Profile/**: プロフィール設定（`ProfileView`）
- **Views/Settings/**: 開発・デバッグ用設定（`CloudKitTestView`）
- **Extensions/**: `View+CornerRadius`, `View+HideKeyboard`, `DateFormatter+Japanese` など
- **Helpers/**: `FileManager`（画像保存）, `MapURLParser`, `OnboardingManager`
- **GoTravelTests/, GoTravelUITests/**: テストターゲット

### Image Handling

画像は `FileManager` 拡張で管理：
- `saveImageDataToDocuments(data:named:)`: Documents ディレクトリに保存
- `documentsImage(named:)`: Documents ディレクトリから取得
- `removeDocumentFile(named:)`: 削除
- ファイル名のみ Core Data に記録し、実データはローカルに保持

## Important Notes

- **iCloud 必須**: データ保存に `NSPersistentCloudKitContainer` を使用するため、iCloud サインインが必要。未サインイン時は `MainTabView` 起動時にアラートを表示
- **認証**: Apple Sign In が必須。`AuthViewModel` がサインイン状態をアプリ全体で管理し、`@EnvironmentObject` として注入される
- **座標系**: 全位置情報に `CLLocationCoordinate2D`（CoreLocation）を使用
- **日本語UI**: アプリのインターフェースは日本語。ロケールは `ja_JP` に固定
- **テーマ**: `ThemeManager.shared` でアプリ全体のカラーテーマを管理。`@ObservedObject` で各 View から参照
- **天気**: `WeatherService`（WeatherKit）で旅行計画の目的地の天気を取得
- **通知**: `NotificationService` で旅行・予定のリマインダー通知をスケジュール管理
