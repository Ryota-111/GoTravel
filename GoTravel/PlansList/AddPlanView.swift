import SwiftUI
import MapKit

struct AddPlanView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var onSave: (Plan) -> Void

    @State private var title: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var places: [PlannedPlace] = []
    @State private var showMapPicker: Bool = false
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    @State private var newPlaceName: String = ""
    @State private var newPlaceAddress: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本")) {
                    TextField("タイトル", text: $title)
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                    DatePicker("終了日", selection: $endDate, displayedComponents: .date)
                }

                Section(header: Text("行きたい場所")) {
                    if places.isEmpty {
                        Text("まだ行きたい場所は登録されていません").foregroundColor(.secondary)
                    } else {
                        ForEach(places) { p in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.name).font(.headline)
                                    if let addr = p.address { Text(addr).font(.caption).foregroundColor(.secondary) }
                                }
                                Spacer()
                                Text("")
                            }
                        }
                        .onDelete { idx in
                            places.remove(atOffsets: idx)
                        }
                    }
                    Button("場所をマップで追加") {
                        newPlaceCoordinate = nil
                        newPlaceName = ""
                        newPlaceAddress = ""
                        showMapPicker = true
                    }
                }
            }
            .navigationTitle("予定を追加")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let normalizedEnd = endDate < startDate ? startDate : endDate
                        let plan = Plan(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                        startDate: startDate,
                                        endDate: normalizedEnd,
                                        places: places)
                        onSave(plan)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || startDate > endDate.addingTimeInterval(60*60*24*365*5))
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $showMapPicker) {
                NavigationView {
                    VStack(spacing: 0) {
                        MapPickerView(coordinate: $newPlaceCoordinate)
                            .edgesIgnoringSafeArea(.all)
                            .frame(height: 380)

                        Form {
                            Section(header: Text("場所情報")) {
                                TextField("場所の名前", text: $newPlaceName)
                                TextField("住所（任意）", text: $newPlaceAddress)
                                HStack {
                                    Spacer()
                                    Button("現在位置を中心に移動") {
                                    }
                                    Spacer()
                                }
                            }
                            Section {
                                Button("追加") {
                                    guard let coord = newPlaceCoordinate else { return }
                                    let p = PlannedPlace(name: newPlaceName.isEmpty ? "無題の場所" : newPlaceName,
                                                         latitude: coord.latitude,
                                                         longitude: coord.longitude,
                                                         address: newPlaceAddress.isEmpty ? nil : newPlaceAddress)
                                    places.append(p)
                                    showMapPicker = false
                                }
                                .disabled(newPlaceCoordinate == nil)
                                Button("キャンセル", role: .cancel) {
                                    showMapPicker = false
                                }
                            }
                        }
                    }
                    .navigationTitle("場所を選択")
                }
            }
        }
    }
}
