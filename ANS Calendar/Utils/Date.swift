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
}
