import SwiftUI

struct ResponsiveWeekView: View {
    @EnvironmentObject var model: ScheduleModel
    @State private var selectedPage: Int = 0
    let hourHeight: CGFloat = 50.0
    
    var body: some View {
        GeometryReader { geometry in
            // 1. Detect Orientation
            let isLandscape = geometry.size.width > geometry.size.height
            let daysPerPage = isLandscape ? 7 : 3
            
            // 2. Calculate column sizes
            let timeColumnWidth: CGFloat = 50
            let dayWidth = (geometry.size.width - timeColumnWidth) / CGFloat(daysPerPage)
            
            // 3. Chunk the current week's days into swipeable pages
            let currentWeekDays = model.Weeks.count > 1 ? model.Weeks[1].Days : []
            let pages = Array(currentWeekDays.chunked(into: daysPerPage).enumerated())
            
            VStack(spacing: 0) {
                // MARK: - Week Navigation Header
                HStack {
                    Button {
                        model.ShiftWeeks(dir: -1)
                        selectedPage = 0
                    } label: {
                        Image(systemName: "chevron.left")
                            .padding()
                    }
                    
                    Spacer()
                    
                    Text(model.SelectedWeek.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        model.ShiftWeeks(dir: 1)
                        selectedPage = 0
                    } label: {
                        Image(systemName: "chevron.right")
                            .padding()
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                
                // MARK: - Swipable Days Grid
                TabView(selection: $selectedPage) {
                    ForEach(pages, id: \.offset) { index, pageDays in
                        DayGridPage(pageDays: pageDays, timeColumnWidth: timeColumnWidth, dayWidth: dayWidth)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .onChange(of: isLandscape) { _ in
                // Reset page to 0 if we rotate the device so we don't end up on a blank page
                selectedPage = 0
            }
        }
    }
    
    // MARK: - Page View Builder
    @ViewBuilder
    func DayGridPage(pageDays: [Date], timeColumnWidth: CGFloat, dayWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Header Row (Day Names and Dates)
            HStack(spacing: 0) {
                Color.clear.frame(width: timeColumnWidth)
                ForEach(pageDays, id: \.self) { day in
                    VStack(spacing: 5) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ZStack {
                            Circle()
                                .fill(day.IsSameDay(date: model.SelectedDay) ? Color.accentColor : Color.clear)
                                .frame(width: 30, height: 30)
                            
                            Text(day.formatted(.dateTime.day()))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(day.IsSameDay(date: model.SelectedDay) ? .white : .primary)
                        }
                    }
                    .frame(width: dayWidth)
                    .onTapGesture {
                        withAnimation {
                            model.SelectDay(day: day)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Timeline Grid
            ScrollView(.vertical) {
                ZStack(alignment: .topLeading) {
                    // Background Time Labels & Lines
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(7..<22) { hour in
                            HStack(spacing: 0) {
                                Text("\(hour):00")
                                    .font(.footnote)
                                    .foregroundStyle(Color.secondary)
                                    .frame(width: timeColumnWidth, alignment: .trailing)
                                    .padding(.trailing, 5)
                                
                                VStack {
                                    Divider()
                                }
                            }
                            .frame(height: hourHeight, alignment: .top)
                        }
                    }
                    
                    // Day Columns & Schedules Overlay
                    HStack(spacing: 0) {
                        Color.clear.frame(width: timeColumnWidth)
                        
                        ForEach(pageDays, id: \.self) { day in
                            ZStack(alignment: .top) {
                                // Vertical divider between days
                                Rectangle()
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Current time indicator
                                if day.IsSameDay(date: Date()) {
                                    ResponsiveTimeIndicator(hourHeight: hourHeight)
                                }
                                
                                // Schedules specifically for this day
                                let daySchedules = model.Schedules.filter {
                                    Date(timeIntervalSince1970: Double($0.dataRozpoczecia / 1000)).IsSameDay(date: day)
                                }
                                
                                ForEach(daySchedules) { schedule in
                                    ResponsiveScheduleCard(schedule: schedule, dayWidth: dayWidth, hourHeight: hourHeight)
                                }
                            }
                            .frame(width: dayWidth, alignment: .top)
                            .clipped() // Prevents cards from bleeding into other days
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 0)
                }
                .padding(.top, 10)
            }
        }
    }
}

// MARK: - Subcomponents

struct ResponsiveScheduleCard: View {
    let schedule: ScheduleInfo
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    
    var body: some View {
        let start = Date(timeIntervalSince1970: Double(schedule.dataRozpoczecia / 1000))
        let end = Date(timeIntervalSince1970: Double(schedule.dataZakonczenia / 1000))
        
        let startHour = CGFloat(start.Hour) + CGFloat(start.Minute) / 60.0
        let endHour = CGFloat(end.Hour) + CGFloat(end.Minute) / 60.0
        
        let topOffset = max(0, (startHour - 7.0)) * hourHeight
        let duration = max(0.25, endHour - startHour)
        let height = duration * hourHeight
        
        VStack(alignment: .leading, spacing: 2) {
            Text(schedule.nazwaPelnaPrzedmiotu)
                .font(.caption)
                .fontWeight(.bold)
                // Hide text if the lesson block is extremely short
                .lineLimit(height < 40 ? 1 : 2)
                .foregroundStyle(.white)
            
            // Only show room if the card has enough height to display it
            if height >= 50 {
                if let room = schedule.sale.first?.nazwaSkrocona {
                    Text(room)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
        }
        .padding(4)
        .frame(width: dayWidth - 4, height: height, alignment: .topLeading)
        .background(schedule.GetLessonColor())
        .cornerRadius(6)
        // Offset slightly to the right to leave a tiny gap between day columns
        .offset(x: 2, y: topOffset)
    }
}

struct ResponsiveTimeIndicator: View {
    let hourHeight: CGFloat
    @State private var timeOffset: CGFloat = 0
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .offset(x: -4)
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
        }
        .offset(y: timeOffset - 4) // Center exactly on the current minute
        .onAppear { updateOffset() }
        .onReceive(timer) { _ in updateOffset() }
        .zIndex(10) // Always appear on top of schedule blocks
    }
    
    private func updateOffset() {
        let now = Date()
        let hours = CGFloat(now.Hour) + CGFloat(now.Minute) / 60.0
        timeOffset = max(0, (hours - 7.0)) * hourHeight
    }
}

// MARK: - Extension Helper
extension Array {
    // Splits an array into smaller chunks (e.g., 3 days at a time)
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
