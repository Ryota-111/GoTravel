import SwiftUI

struct EditTravelPlanView: View {
    @Environment(\.presentationMode) var presentationMode
    var onSave: (TravelPlan) -> Void

    let plan: TravelPlan
    @State private var title: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var daySchedules: [DaySchedule]
    @State private var isUploading = false
    @State private var selectedDayToEdit: DaySchedule?
    @State private var showDayScheduleEditor = false

    init(plan: TravelPlan, onSave: @escaping (TravelPlan) -> Void) {
        self.plan = plan
        self.onSave = onSave
        _title = State(initialValue: plan.title)
        _destination = State(initialValue: plan.destination)
        _startDate = State(initialValue: plan.startDate)
        _endDate = State(initialValue: plan.endDate)
        _daySchedules = State(initialValue: plan.daySchedules)

        if let localImageFileName = plan.localImageFileName,
           let image = FileManager.documentsImage(named: localImageFileName) {
            _selectedImage = State(initialValue: image)
        }
    }

    var tripDuration: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                headerView

                ScrollView {
                    VStack(spacing: 20) {
                        basicInfoSection
                        imagePickerSection
                        daySchedulesSection
                    }
                    .padding()
                }

                saveButton
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showDayScheduleEditor) {
            if let daySchedule = selectedDayToEdit {
                DayScheduleEditorView(
                    daySchedule: binding(for: daySchedule),
                    onSave: { updatedDay in
                        if let index = daySchedules.firstIndex(where: { $0.id == updatedDay.id }) {
                            daySchedules[index] = updatedDay
                        }
                    }
                )
            }
        }
    }

    private func binding(for daySchedule: DaySchedule) -> Binding<DaySchedule> {
        guard let index = daySchedules.firstIndex(where: { $0.id == daySchedule.id }) else {
            return .constant(daySchedule)
        }
        return $daySchedules[index]
    }

    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .imageScale(.large)
                Text("戻る")
                    .foregroundColor(.white)
            }

            Spacer()

            Text("旅行計画を編集")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.2))
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("基本情報")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            customTextField(
                icon: "text.alignleft",
                placeholder: "タイトル",
                text: $title
            )

            customTextField(
                icon: "mappin.circle",
                placeholder: "目的地",
                text: $destination
            )

            VStack(spacing: 15) {
                datePickerCard(title: "開始日", date: $startDate)
                datePickerCard(title: "終了日", date: $endDate)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("カード表紙の写真")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if let image = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .cornerRadius(15)
                        .clipped()

                    Button(action: {
                        selectedImage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(8)
                }
            } else {
                Button(action: {
                    showImagePicker = true
                }) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.7))

                        Text("写真を選択")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(15)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(sourceType: .photoLibrary, image: $selectedImage)
        }
    }

    private var daySchedulesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("スケジュール")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            ForEach(1...tripDuration, id: \.self) { day in
                if let daySchedule = daySchedules.first(where: { $0.dayNumber == day }) {
                    dayScheduleCard(daySchedule)
                } else {
                    emptyDayCard(dayNumber: day)
                }
            }

            Button(action: generateDaySchedules) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                    Text("日程に合わせてスケジュールを生成")
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.5))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
    }

    private func dayScheduleCard(_ daySchedule: DaySchedule) -> some View {
        Button(action: {
            selectedDayToEdit = daySchedule
            showDayScheduleEditor = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Day \(daySchedule.dayNumber)")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(formatDate(daySchedule.date))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text("\(daySchedule.scheduleItems.count)件の予定")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
        }
    }

    private func emptyDayCard(dayNumber: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Day \(dayNumber)")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))

            Text("スケジュールがありません")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    private var saveButton: some View {
        Button(action: saveTravelPlan) {
            HStack {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("保存中...")
                        .foregroundColor(.white)
                } else {
                    Text("保存")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
            .shadow(radius: 10)
        }
        .padding()
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                  destination.trimmingCharacters(in: .whitespaces).isEmpty ||
                  startDate > endDate || isUploading)
    }

    private func customTextField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private func datePickerCard(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .foregroundColor(.white)
                .font(.headline)
            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private func generateDaySchedules() {
        var newSchedules: [DaySchedule] = []
        let calendar = Calendar.current

        for day in 1...tripDuration {
            if let existingSchedule = daySchedules.first(where: { $0.dayNumber == day }) {
                newSchedules.append(existingSchedule)
            } else {
                let dayDate = calendar.date(byAdding: .day, value: day - 1, to: startDate) ?? startDate
                let newSchedule = DaySchedule(
                    dayNumber: day,
                    date: dayDate,
                    scheduleItems: []
                )
                newSchedules.append(newSchedule)
            }
        }

        daySchedules = newSchedules.sorted(by: { $0.dayNumber < $1.dayNumber })
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    private func saveTravelPlan() {
        isUploading = true
        let normalizedEnd = endDate < startDate ? startDate : endDate

        func saveWithImage(_ fileName: String?) {
            let updatedPlan = TravelPlan(
                id: plan.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startDate: startDate,
                endDate: normalizedEnd,
                destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
                localImageFileName: fileName,
                cardColor: plan.cardColor ?? Color.blue,
                createdAt: plan.createdAt,
                userId: plan.userId,
                daySchedules: daySchedules
            )
            onSave(updatedPlan)
            isUploading = false
            presentationMode.wrappedValue.dismiss()
        }

        if let image = selectedImage {
            if let existingFileName = plan.localImageFileName,
               FileManager.documentsImage(named: existingFileName) == image {
                saveWithImage(existingFileName)
            } else {
                FirestoreService.shared.saveTravelPlanImageLocally(image) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let fileName):
                            if let oldFileName = plan.localImageFileName {
                                FirestoreService.shared.deleteTravelPlanImageLocally(oldFileName)
                            }
                            saveWithImage(fileName)
                        case .failure:
                            saveWithImage(plan.localImageFileName)
                        }
                    }
                }
            }
        } else {
            if let oldFileName = plan.localImageFileName {
                FirestoreService.shared.deleteTravelPlanImageLocally(oldFileName)
            }
            saveWithImage(nil)
        }
    }
}

struct DayScheduleEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var daySchedule: DaySchedule
    var onSave: (DaySchedule) -> Void

    @State private var showAddScheduleItem = false
    @State private var scheduleItemToEdit: ScheduleItem?

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack {
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(daySchedule.scheduleItems.sorted(by: { $0.time < $1.time })) { item in
                                scheduleItemRow(item)
                            }

                            Button(action: { showAddScheduleItem = true }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("予定を追加")
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.5))
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Day \(daySchedule.dayNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        onSave(daySchedule)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showAddScheduleItem) {
                AddScheduleItemEditorView(daySchedule: $daySchedule)
            }
        }
    }

    private func scheduleItemRow(_ item: ScheduleItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(formatTime(item.time))
                    .font(.caption)
                    .foregroundColor(.orange)

                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.white)

                if let location = item.location {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()

            Button(action: {
                if let index = daySchedule.scheduleItems.firstIndex(where: { $0.id == item.id }) {
                    daySchedule.scheduleItems.remove(at: index)
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct AddScheduleItemEditorView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var daySchedule: DaySchedule

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var time: Date = Date()

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        customTextField(icon: "text.alignleft", placeholder: "タイトル", text: $title)
                        customTextField(icon: "mappin.circle", placeholder: "場所", text: $location)
                        customTextField(icon: "note.text", placeholder: "メモ", text: $notes)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("時間")
                                .foregroundColor(.white)
                                .font(.headline)
                            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                        }
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationTitle("予定を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let newItem = ScheduleItem(
                            time: time,
                            title: title,
                            location: location.isEmpty ? nil : location,
                            notes: notes.isEmpty ? nil : notes
                        )
                        daySchedule.scheduleItems.append(newItem)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func customTextField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
            TextField(placeholder, text: text)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(10)
    }
}
