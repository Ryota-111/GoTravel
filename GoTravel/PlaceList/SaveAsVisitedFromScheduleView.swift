import SwiftUI
import CoreLocation

struct SaveAsVisitedFromScheduleView: View {
    let scheduleItem: ScheduleItem
    let travelPlanTitle: String
    let travelPlanId: String?

    @Environment(\.presentationMode) var presentationMode
    @State private var notes: String
    @State private var selectedCategory: PlaceCategory = .sightseeing
    @State private var visitedDate: Date = Date()
    @State private var isSaving = false

    init(scheduleItem: ScheduleItem, travelPlanTitle: String, travelPlanId: String?) {
        self.scheduleItem = scheduleItem
        self.travelPlanTitle = travelPlanTitle
        self.travelPlanId = travelPlanId
        _notes = State(initialValue: scheduleItem.notes ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("スケジュール情報")) {
                    HStack {
                        Text("タイトル")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(scheduleItem.title)
                    }

                    if let location = scheduleItem.location {
                        HStack {
                            Text("場所")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(location)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    HStack {
                        Text("予定時刻")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(scheduleItem.time))
                    }
                }

                Section(header: Text("訪問情報")) {
                    HStack {
                        Text("旅行タイトル")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(travelPlanTitle)
                    }

                    DatePicker("訪問日", selection: $visitedDate, displayedComponents: .date)
                }

                Section(header: Text("カテゴリー")) {
                    Picker("カテゴリー", selection: $selectedCategory) {
                        ForEach(PlaceCategory.allCases) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("メモ")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section(header: Text("位置情報")) {
                    if let mapURL = scheduleItem.mapURL, !mapURL.isEmpty {
                        HStack {
                            Text("地図URL")
                                .foregroundColor(.secondary)
                            Spacer()
                            Link(destination: URL(string: mapURL)!) {
                                Image(systemName: "map.fill")
                                    .foregroundColor(.blue)
                            }
                        }

                        if let coordinate = MapURLParser.extractCoordinate(from: mapURL) {
                            HStack {
                                Text("座標 (URL)")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                                    .font(.caption)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    if scheduleItem.latitude != nil && scheduleItem.longitude != nil {
                        HStack {
                            Text("座標 (直接)")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.4f, %.4f", scheduleItem.latitude ?? 0, scheduleItem.longitude ?? 0))
                                .font(.caption)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    if scheduleItem.mapURL == nil && scheduleItem.latitude == nil {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("位置情報がありません")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("訪問地として保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveVisitedPlace()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func saveVisitedPlace() {
        isSaving = true

        // mapURLから座標を取得する試み
        var latitude = scheduleItem.latitude ?? 0
        var longitude = scheduleItem.longitude ?? 0

        // latitude/longitudeが設定されていない場合、mapURLから抽出
        if (latitude == 0 && longitude == 0), let mapURL = scheduleItem.mapURL {
            if let coordinate = MapURLParser.extractCoordinate(from: mapURL) {
                latitude = coordinate.latitude
                longitude = coordinate.longitude
                print("📍 mapURLから座標を抽出: \(latitude), \(longitude)")
            } else {
                print("⚠️ mapURLから座標を抽出できませんでした: \(mapURL)")
            }
        }

        let visitedPlace = VisitedPlace(
            title: travelPlanTitle + " - " + scheduleItem.title,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? scheduleItem.notes : notes.trimmingCharacters(in: .whitespaces),
            latitude: latitude,
            longitude: longitude,
            createdAt: Date(),
            visitedAt: visitedDate,
            category: selectedCategory,
            travelPlanId: travelPlanId
        )

        FirestoreService.shared.save(place: visitedPlace, image: nil) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    print("✅ 訪問地として保存成功")
                    presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    print("❌ 訪問地の保存エラー: \(error.localizedDescription)")
                }
            }
        }
    }
}
