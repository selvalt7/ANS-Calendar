//
//  TabbedDay.swift
//  ANS Calendar
//
//  Created by Stanisław on 23/11/2024.
//

import SwiftUI

struct TabbedDay<Content: View>: View {
    @EnvironmentObject var model: ScheduleModel
    @EnvironmentObject var VerbisAPI: VerbisAPI
    @State private var selectedPage: Int = 1
    @State private var dir: Int = 0
    @State private var offset: CGFloat = CGFloat.zero
    
    let content: (_ date: Date) -> Content
    
    init(@ViewBuilder content: @escaping (_ date: Date) -> Content) {
        self.content = content
    }
    
    var body: some View {
        VStack {
            TabView(selection: $selectedPage) {
                VStack(spacing: 0) {
                    Text(model.SelectedDay.Yesterday.formatted(date: .abbreviated, time: .omitted))
                        .padding(8)
                    Divider()
                    ScrollView {
                        content(model.SelectedDay.Yesterday)
                            .offset(y: offset)
                    }
                }
                    .tag(0)
                VStack(spacing: 0) {
                    Text(model.SelectedDay.formatted(date: .abbreviated, time: .omitted))
                        .padding(8)
                    Divider()
                    ScrollView {
                        content(model.SelectedDay)
                            .background(GeometryReader { proxy -> Color in
                                DispatchQueue.main.async {
                                    offset = proxy.frame(in: .named("scroll")).origin.y
                                }
                                return Color.clear
                            })
                    }
                    .coordinateSpace(.named("scroll"))
                }
                    .tag(1)
                    .onDisappear() {
                        if dir != 0 {
                            if dir == -1 {
                                model.SelectDay(day: model.SelectedDay.Yesterday)
                            } else if dir == 1 {
                                model.SelectDay(day: model.SelectedDay.Tomorrow)
                            }
                        }
                        
                        if !model.SelectedDay.IsSameWeek(date: model.SelectedWeek) {
                            model.ShiftWeeks(dir: 0)
                            Task {
                                try await model.LoadSchedule(VerbisANSApi: VerbisAPI)
                            }
                        }
                        
                        dir = 0
                        selectedPage = 1
                    }
                VStack(spacing: 0) {
                    Text(model.SelectedDay.Tomorrow.formatted(date: .abbreviated, time: .omitted))
                        .padding(8)
                    Divider()
                    ScrollView {
                        content(model.SelectedDay.Tomorrow)
                            .offset(y: offset)
                    }
                }
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selectedPage) { value in
                if value == 0 {
                    dir = -1
                } else if value == 2 {
                    dir = 1
                }
            }
        }
    }
}

#Preview {
    TabbedDay() { date in
        Text(date.formatted())
    }
    .environmentObject(ScheduleModel())
    .environmentObject(VerbisAPI())
}
