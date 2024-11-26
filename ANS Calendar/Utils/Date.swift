//
//  Date.swift
//  ANS Calendar
//
//  Created by Stanisław on 19/11/2024.
//

import Foundation

extension Date {
    func GetDateComponentFromUnix(Unix: Int, Component: Calendar.Component) -> Int {
        let date = Date(timeIntervalSince1970: Double(Unix / 1000))
        return Calendar.current.component(Component, from: date)
    }
    
    func GetDateComponent(Date: Date, Component: Calendar.Component) -> Int {
        return Calendar.current.component(Component, from: Date)
    }
    
    func startOfWeek(using calendar: Calendar = .current) -> Date {
        return calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date!
    }
    
    func GetShortDayName() -> String {
        let Formatter = DateFormatter()
        Formatter.dateFormat = "EE"
        return Formatter.string(from: self)
    }
    
    func IsSameDay(date: Date) -> Bool {
        return Calendar.current.isDate(self, equalTo: date, toGranularity: .day)
    }
    
    func IsSameWeek(date: Date) -> Bool {
        return Calendar.current.isDate(self, equalTo: date, toGranularity: .weekOfYear)
    }
    
    var Yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: self)!
    }
    
    var Tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: self)!
    }
    
    var Hour: Int {
        Calendar.current.component(.hour, from: self)
    }
    
    var Minute: Int {
        Calendar.current.component(.minute, from: self)
    }
}

