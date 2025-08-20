//
//  DailyChallengeView.swift
//  RuneWords
//
//  Enhanced daily challenge with calendar, streaks, and rewards
//

import SwiftUI
import Combine

// MARK: - View Model
@MainActor
class DailyChallengeViewModel: ObservableObject {
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var completedDates: Set<Date> = []
    @Published var hasPlayedToday: Bool = false
    @Published var todayReward: Int = 50
    @Published var nextMilestone: Int? = nil
    @Published var selectedMonth: Date = Date()
    @Published var showingRewardAnimation: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadPlayerData()
        setupBindings()
        calculateRewards()
    }
    
    private func loadPlayerData() {
        guard let player = PlayerService.shared.player else { return }
        
        currentStreak = player.dailyStreak
        longestStreak = UserDefaults.standard.integer(forKey: "longestDailyStreak")
        
        // Load completed dates from player data
        if let lastDaily = player.lastDailyDate {
            let today = DailyChallengeService.dateKey(for: Date())
            hasPlayedToday = (lastDaily == today)
        }
        
        // Calculate next milestone
        let milestones = [7, 14, 30, 60, 100]
        nextMilestone = milestones.first { $0 > currentStreak }
    }
    
    private func setupBindings() {
        PlayerService.shared.$player
            .compactMap { $0 }  // This is Player?, not PlayerData?
            .sink { [weak self] player in
                self?.currentStreak = player.dailyStreak
                self?.checkTodayStatus(player: player)
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: .dailyChallengeCompleted)
            .sink { [weak self] _ in
                self?.hasPlayedToday = true
                self?.showRewardAnimation()
            }
            .store(in: &cancellables)
    }
    
    private func checkTodayStatus(player: Player) {
        let todayKey = DailyChallengeService.dateKey(for: Date())
        hasPlayedToday = (player.lastDailyDate == todayKey)
    }
    
    private func calculateRewards() {
        // Base reward + streak bonus
        let baseReward = 50
        let streakBonus = min(currentStreak * 5, 100)
        todayReward = baseReward + streakBonus
        
        // Milestone bonus
        if let milestone = nextMilestone, currentStreak == milestone - 1 {
            todayReward += 100
        }
    }
    
    func canPlay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: date)
        
        // Can only play today's challenge
        return selectedDay == today && !hasPlayedToday
    }
    
    func milestoneReward(for milestone: Int) -> String {
        switch milestone {
        case 7: return "🎁 50 Coins + Clarity Rune"
        case 14: return "🎁 100 Coins + Revelation Rune"
        case 30: return "🎁 200 Coins + Premium Pack"
        case 60: return "🎁 500 Coins + Legendary Wisp"
        case 100: return "🎁 1000 Coins + Crown Collection"
        default: return "🎁 Special Reward"
        }
    }
    
    private func showRewardAnimation() {
        showingRewardAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showingRewardAnimation = false
        }
    }
    
    func getCompletionStatus(for date: Date) -> CompletionStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        
        if checkDate > today {
            return .future
        } else if checkDate == today {
            return hasPlayedToday ? .completed : .available
        } else {
            return completedDates.contains(checkDate) ? .completed : .missed
        }
    }
    
    enum CompletionStatus {
        case completed, available, missed, future
        
        var color: Color {
            switch self {
            case .completed: return .green
            case .available: return .yellow
            case .missed: return .gray
            case .future: return .clear
            }
        }
        
        var icon: String? {
            switch self {
            case .completed: return "checkmark.circle.fill"
            case .available: return "play.circle.fill"
            case .missed: return "xmark.circle"
            case .future: return nil
            }
        }
    }
}

// MARK: - Main View
struct DailyChallengeView: View {
    @StateObject private var viewModel = DailyChallengeViewModel()
    @State private var selectedDate = Date()
    @State private var showingLevelSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            DailyChallengeBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with streak
                    DailyChallengeHeader(
                        streak: viewModel.currentStreak,
                        longestStreak: viewModel.longestStreak
                    )
                    
                    // Calendar
                    CalendarView(
                        selectedDate: $selectedDate,
                        selectedMonth: $viewModel.selectedMonth,
                        getStatus: viewModel.getCompletionStatus
                    )
                    .padding(.horizontal)
                    
                    // Today's challenge card
                    TodaysChallengeCard(
                        hasPlayed: viewModel.hasPlayedToday,
                        reward: viewModel.todayReward,
                        onPlay: {
                            showingLevelSheet = true
                        }
                    )
                    .padding(.horizontal)
                    
                    // Milestone progress
                    if let nextMilestone = viewModel.nextMilestone {
                        MilestoneProgressCard(
                            current: viewModel.currentStreak,
                            target: nextMilestone,
                            reward: viewModel.milestoneReward(for: nextMilestone)
                        )
                        .padding(.horizontal)
                    }
                    
                    // Rewards section
                    RewardsSection()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            
            // Reward animation overlay
            if viewModel.showingRewardAnimation {
                RewardAnimationOverlay(coins: viewModel.todayReward)
            }
        }
        .navigationTitle("Daily Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingLevelSheet) {
            NavigationView {
                GameView(isDailyChallenge: true)
                    .navigationTitle("Daily Challenge")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                showingLevelSheet = false
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Components
struct DailyChallengeBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.3),
                Color.yellow.opacity(0.2),
                Color.orange.opacity(0.3)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

struct DailyChallengeHeader: View {
    let streak: Int
    let longestStreak: Int
    @State private var flameAnimation = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Streak display
            HStack(spacing: 20) {
                // Current streak
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                            .scaleEffect(flameAnimation ? 1.2 : 1.0)
                        
                        Text("\(streak)")
                            .font(.custom("Cinzel-Bold", size: 48))
                            .foregroundColor(.white)
                    }
                    
                    Text("Current Streak")
                        .font(.custom("Cinzel-Regular", size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Divider()
                    .frame(height: 60)
                    .background(Color.white.opacity(0.3))
                
                // Longest streak
                VStack(spacing: 8) {
                    Text("\(longestStreak)")
                        .font(.custom("Cinzel-Bold", size: 32))
                        .foregroundColor(.yellow)
                    
                    Text("Best Streak")
                        .font(.custom("Cinzel-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
        .onAppear {
            if streak > 0 {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    flameAnimation = true
                }
            }
        }
    }
}

struct CalendarView: View {
    @Binding var selectedDate: Date
    @Binding var selectedMonth: Date
    let getStatus: (Date) -> DailyChallengeViewModel.CompletionStatus
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedMonth))
                    .font(.custom("Cinzel-Bold", size: 20))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            
            // Calendar grid
            CalendarGridView(
                month: selectedMonth,
                selectedDate: $selectedDate,
                getStatus: getStatus
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func previousMonth() {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
        }
    }
    
    private func nextMonth() {
        withAnimation {
            selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
        }
    }
}

struct CalendarGridView: View {
    let month: Date
    @Binding var selectedDate: Date
    let getStatus: (Date) -> DailyChallengeViewModel.CompletionStatus
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 12) {
            // Day labels
            HStack {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.custom("Cinzel-Bold", size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(getDaysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            status: getStatus(date),
                            onTap: {
                                withAnimation {
                                    selectedDate = date
                                }
                            }
                        )
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
    }
    
    private func getDaysInMonth() -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in monthRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Fill remaining cells
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let status: DailyChallengeViewModel.CompletionStatus
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                Circle()
                    .fill(cellBackground)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 2)
                    )
                
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.custom("Cinzel-Bold", size: 16))
                    .foregroundColor(textColor)
                
                // Status icon
                if let icon = status.icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(status.color)
                        .offset(x: 12, y: -12)
                }
            }
            .frame(width: 40, height: 40)
        }
    }
    
    private var cellBackground: Color {
        switch status {
        case .completed:
            return Color.green.opacity(0.3)
        case .available:
            return Color.yellow.opacity(0.3)
        case .missed:
            return Color.gray.opacity(0.2)
        case .future:
            return Color.clear
        }
    }
    
    private var textColor: Color {
        switch status {
        case .completed, .available:
            return .white
        case .missed:
            return .gray
        case .future:
            return .white.opacity(0.3)
        }
    }
}

struct TodaysChallengeCard: View {
    let hasPlayed: Bool
    let reward: Int
    let onPlay: () -> Void
    @State private var glowAnimation = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Challenge")
                        .font(.custom("Cinzel-Bold", size: 20))
                        .foregroundColor(.white)
                    
                    Text(Date(), style: .date)
                        .font(.custom("Cinzel-Regular", size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Reward preview
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Image("icon_coin")
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text("+\(reward)")
                            .font(.custom("Cinzel-Bold", size: 20))
                            .foregroundColor(.yellow)
                    }
                    
                    Text("Reward")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // Play button
            Button(action: onPlay) {
                HStack {
                    Image(systemName: hasPlayed ? "checkmark.circle.fill" : "play.fill")
                    Text(hasPlayed ? "Completed" : "Play Now")
                }
                .font(.custom("Cinzel-Bold", size: 18))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    hasPlayed ? Color.gray : Color.orange
                )
                .cornerRadius(15)
                .shadow(color: glowAnimation && !hasPlayed ? Color.orange.opacity(0.5) : Color.clear, radius: 10)
            }
            .disabled(hasPlayed)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            if !hasPlayed {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
    }
}

struct MilestoneProgressCard: View {
    let current: Int
    let target: Int
    let reward: String
    
    private var progress: CGFloat {
        CGFloat(current) / CGFloat(target)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Milestone")
                .font(.custom("Cinzel-Bold", size: 18))
                .foregroundColor(.white)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 20)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 20)
                }
                .overlay(
                    Text("\(current) / \(target)")
                        .font(.custom("Cinzel-Bold", size: 12))
                        .foregroundColor(.white)
                )
            }
            .frame(height: 20)
            
            // Reward
            Text(reward)
                .font(.custom("Cinzel-Regular", size: 14))
                .foregroundColor(.yellow)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

struct RewardsSection: View {
    let milestones = [
        (days: 7, icon: "gift", title: "Week Warrior"),
        (days: 14, icon: "star.circle", title: "Fortnight Master"),
        (days: 30, icon: "crown", title: "Monthly Champion"),
        (days: 60, icon: "trophy", title: "Elite Challenger"),
        (days: 100, icon: "rosette", title: "Century Legend")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Milestone Rewards")
                .font(.custom("Cinzel-Bold", size: 20))
                .foregroundColor(.white)
            
            ForEach(milestones, id: \.days) { milestone in
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: milestone.icon)
                            .font(.system(size: 24))
                            .foregroundColor(.yellow)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(milestone.title)
                            .font(.custom("Cinzel-Bold", size: 16))
                            .foregroundColor(.white)
                        
                        Text("\(milestone.days) Day Streak")
                            .font(.custom("Cinzel-Regular", size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Check if achieved
                    if PlayerService.shared.player?.dailyStreak ?? 0 >= milestone.days {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

struct RewardAnimationOverlay: View {
    let coins: Int
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background dim
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // Reward display
            VStack(spacing: 20) {
                // Coins
                HStack(spacing: 8) {
                    Image("icon_coin")
                        .resizable()
                        .frame(width: 60, height: 60)
                    
                    Text("+\(coins)")
                        .font(.custom("Cinzel-Bold", size: 48))
                        .foregroundColor(.yellow)
                }
                .scaleEffect(scale)
                .offset(y: offset)
                
                Text("Daily Challenge Complete!")
                    .font(.custom("Cinzel-Bold", size: 24))
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                offset = -20
            }
        }
    }
}