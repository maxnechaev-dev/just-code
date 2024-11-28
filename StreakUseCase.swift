//
//  StreakUseCase.swift
//  eduva
//
//  Created by Max Nechaev on 05.09.2024.
//

import Foundation
import SwiftUI

final class StreakUseCase {
    @AppStorage("lastVisitDate") private var lastVisitDateString: String = ""
    @AppStorage("currentStreak") private var currentStreak: Int = 0
    @AppStorage("lastUpdatedDate") private var lastUpdatedDateString: String = ""

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    /// Get current streak number of days
    func getCurrentStreak() -> Int {
        let today = Date()
        let calendar = Calendar.current

        if let lastVisitDate = convertStringToDate(lastVisitDateString) {
            if let difference = calendar.dateComponents([.day], from: lastVisitDate, to: today).day, difference > 1 {
                // Сброс стрика
                currentStreak = 0
            }
        } else {
            currentStreak = 0
        }

        return currentStreak
    }

    /// Add date to streak
    func addDate(_ date: Date) {
        let calendar = Calendar.current

        if let lastUpdatedDate = convertStringToDate(lastUpdatedDateString), calendar.isDate(lastUpdatedDate, inSameDayAs: date) {
            return
        }

        if let lastVisitDate = convertStringToDate(lastVisitDateString) {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
               calendar.isDate(lastVisitDate, inSameDayAs: yesterday) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        
        lastVisitDateString = dateFormatter.string(from: date)
        lastUpdatedDateString = dateFormatter.string(from: date)
    }

    func getLastStreakDate() -> Date? {
        convertStringToDate(lastVisitDateString)
    }

    /// Convert string from memory to valid Date, if no dates founded - return nil
    private func convertStringToDate(_ value: String) -> Date? {
        return dateFormatter.date(from: value)
    }
}
