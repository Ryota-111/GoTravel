import SwiftUI

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

        print("SaveAsVisitedFromScheduleView: 保存開始")
        print("scheduleItem.mapURL: \(scheduleItem.mapURL ?? "なし")")

        DispatchQueue.global(qos: .userInitiated).async {
            var address: String? = scheduleItem.location

            if let mapURL = scheduleItem.mapURL {
                if let extractedAddress = MapURLParser.extractAddress(from: mapURL) {
                    address = extractedAddress
                    print("mapURLから住所を抽出: \(extractedAddress)")
                } else {
                    print("mapURLから住所を抽出できませんでした")
                }
            }

            print("保存する住所: \(address ?? "なし")")

            let visitedPlace = VisitedPlace(
                title: travelPlanTitle + " - " + scheduleItem.title,
                notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? scheduleItem.notes : notes.trimmingCharacters(in: .whitespaces),
                createdAt: Date(),
                visitedAt: visitedDate,
                address: address,
                category: selectedCategory,
                travelPlanId: travelPlanId
            )

            FirestoreService.shared.save(place: visitedPlace, image: nil) { result in
                DispatchQueue.main.async {
                    isSaving = false
                    switch result {
                    case .success:
                        print("訪問地として保存成功")
                        presentationMode.wrappedValue.dismiss()
                    case .failure(let error):
                        print("訪問地の保存エラー: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
