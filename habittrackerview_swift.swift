import SwiftUI
import Combine

// MARK: - Models
struct Habit: Identifiable, Codable {
    let id: UUID
    var title: String
    var targetPerDay: Int
    var completedToday: Int
    var lastUpdatedDate: Date
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        targetPerDay: Int,
        completedToday: Int = 0,
        lastUpdatedDate: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.targetPerDay = targetPerDay
        self.completedToday = completedToday
        self.lastUpdatedDate = lastUpdatedDate
        self.createdAt = createdAt
    }

    var isCompletedToday: Bool {
        completedToday >= targetPerDay
    }
}

// MARK: - Store / State Management
@MainActor
final class HabitStore: ObservableObject {
    @Published var habits: [Habit] = [] {
        didSet { save() }
    }

    private let saveKey = "LiquidGlassHabits_SingleFile_Data"

    init() {
        load()
        checkAndResetDailyProgress()
    }

    func checkAndResetDailyProgress() {
        let calendar = Calendar.current
        var isUpdated = false

        for index in habits.indices {
            if !calendar.isDateInToday(habits[index].lastUpdatedDate) {
                habits[index].completedToday = 0
                habits[index].lastUpdatedDate = Date()
                isUpdated = true
            }
        }

        if isUpdated { save() }
    }

    func addHabit(title: String, targetPerDay: Int) {
        let newHabit = Habit(title: title, targetPerDay: targetPerDay)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            habits.append(newHabit)
        }
    }

    func incrementHabit(_ habit: Habit) {
        guard let index = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        if habits[index].completedToday < habits[index].targetPerDay {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                habits[index].completedToday += 1
                habits[index].lastUpdatedDate = Date()
            }
        }
    }

    func deleteHabit(_ habit: Habit) {
        withAnimation(.easeInOut) {
            habits.removeAll(where: { $0.id == habit.id })
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONEncoder().decode([Habit].self, from: data) {
            self.habits = decoded
        } else {
            self.habits = [
                Habit(title: "Выпить 2L воды", targetPerDay: 4),
                Habit(title: "Утренняя разминка", targetPerDay: 1)
            ]
        }
    }
}

// MARK: - Liquid Glass Styles & Background
struct LiquidGlassStyle: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeft,
                            endPoint: .bottomRight
                        ),
                        lineWidth: 1.2
                    )
            )
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 24) -> some View {
        self.modifier(LiquidGlassStyle(cornerRadius: cornerRadius))
    }
}

struct AnimatedGlassBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0b0f19"), Color(hex: "111827")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            Circle()
                .fill(Color(hex: "6366f1").opacity(0.45))
                .frame(width: 340, height: 340)
                .blur(radius: 75)
                .offset(x: animate ? -90 : 90, y: animate ? -160 : -40)

            Circle()
                .fill(Color(hex: "ec4899").opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: animate ? 110 : -70, y: animate ? 220 : 80)

            Circle()
                .fill(Color(hex: "06b6d4").opacity(0.35))
                .frame(width: 260, height: 260)
                .blur(radius: 65)
                .offset(x: animate ? -60 : 70, y: animate ? 320 : -180)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Components
struct SwipeSliderView: View {
    var isCompleted: Bool
    var onSwipeComplete: () -> Void

    @State private var offset: CGFloat = 0
    private let buttonSize: CGFloat = 48

    var body: some View {
        GeometryReader { geometry in
            let maxOffset = geometry.size.width - buttonSize - 8

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "38bdf8"), Color(hex: "818cf8")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(buttonSize + 8, offset + buttonSize + 4))
                    .opacity(isCompleted ? 1 : (offset > 0 ? 0.9 : 0.3))

                HStack {
                    Spacer()
                    Text(isCompleted ? "Цель выполнена ✨" : "Свайп вправо →")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(isCompleted ? 0.95 : 0.6))
                    Spacer()
                }

                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                    )
                    .overlay(
                        Image(systemName: isCompleted ? "checkmark" : "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isCompleted ? Color(hex: "34d399") : .white)
                    )
                    .frame(width: buttonSize, height: buttonSize)
                    .padding(.leading, 4)
                    .offset(x: isCompleted ? maxOffset : offset)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                guard !isCompleted else { return }
                                if gesture.translation.width > 0 {
                                    self.offset = min(gesture.translation.width, maxOffset)
                                }
                            }
                            .onEnded { _ in
                                guard !isCompleted else { return }
                                if self.offset > maxOffset * 0.75 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        self.offset = maxOffset
                                    }
                                    
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    onSwipeComplete()
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                            self.offset = 0
                                        }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        self.offset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 56)
    }
}

struct HabitRowView: View {
    let habit: Habit
    var onIncrement: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("\(habit.completedToday) из \(habit.targetPerDay) за сегодня")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 4)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: CGFloat(habit.completedToday) / CGFloat(habit.targetPerDay))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "34d399"), Color(hex: "059669")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: habit.completedToday)

                    if habit.isCompletedToday {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "34d399"))
                    } else {
                        Text("\(Int((Double(habit.completedToday) / Double(habit.targetPerDay)) * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }

            SwipeSliderView(
                isCompleted: habit.isCompletedToday,
                onSwipeComplete: onIncrement
            )
        }
        .padding(18)
        .liquidGlass(cornerRadius: 24)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Удалить привычку", systemImage: "trash")
            }
        }
    }
}

// MARK: - Views
struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: HabitStore

    @State private var title: String = ""
    @State private var targetPerDay: Int = 1

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGlassBackground()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Название привычки")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))

                        TextField("Например: Чтение 20 минут", text: $title)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Повторений в день")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            Text("\(targetPerDay)x")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "38bdf8"))
                        }

                        Stepper("", value: $targetPerDay, in: 1...20)
                            .labelsHidden()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Spacer()

                    Button(action: saveHabit) {
                        Text("Создать привычку")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "6366f1"), Color(hex: "a855f7")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                            .shadow(color: Color(hex: "6366f1").opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                }
                .padding(24)
            }
            .navigationTitle("Новая привычка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func saveHabit() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addHabit(title: trimmed, targetPerDay: targetPerDay)
        dismiss()
    }
}

public struct MainHabitTrackerView: View {
    @StateObject private var store = HabitStore()
    @State private var isAddingHabit = false

    public init() {}

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date()).capitalized
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(formattedDate)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "38bdf8"))
                                .textCase(.uppercase)

                            HStack {
                                Text("Сегодня")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                Button(action: { isAddingHabit = true }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .padding(.top, 10)

                        if store.habits.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white.opacity(0.6))

                                Text("Нет привычек на сегодня")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                Text("Нажмите '+', чтобы добавить новую.")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                            .liquidGlass()
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(store.habits) { habit in
                                    HabitRowView(
                                        habit: habit,
                                        onIncrement: { store.incrementHabit(habit) },
                                        onDelete: { store.deleteHabit(habit) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .sheet(isPresented: $isAddingHabit) {
                AddHabitView(store: store)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                store.checkAndResetDailyProgress()
            }
        }
        .preferredColorScheme(.dark)
    }
}