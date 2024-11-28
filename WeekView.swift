//
//  WeekView.swift
//  Planner
//
//  Created by Max Nechaev on 03.05.2024.
//

import SwiftUI

struct WeekView: View {
    @StateObject var weekViewModel = WeekViewModel()

    let week: [Date.WeekDay]
    @Binding var currentDate: Date
    @Binding var createWeek: Bool
    let paginateWeek: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(week) { day in
                let dayProgress = weekViewModel.checkDayStatus(date: day.date)
                VStack(spacing: 8) {
                    Text(day.date.format("EEEEEE"))
                        .setFont(.medium, size: 14)
                        .foregroundStyle(weekdayColor(day, progress: dayProgress))

                    dayView(day.date, progress: dayProgress)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background(content: {
                    backgroundShape(day)
                })
                .hSpacing(.center)
                .contentShape(.rect)
                .onTapGesture {
                    /// Updating Current Date
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    currentDate = day.date
                }
            }
        }
        .background {
            GeometryReader {
                let minX = $0.frame(in: .global).minX

                Color.clear
                    .preference(key: OffsetKey.self, value: minX)
                    .onPreferenceChange(OffsetKey.self) { value in
                        if (abs(value) >= 0 && abs(value) < 1) && createWeek {
                            paginateWeek()
                            createWeek = false
                        }
                    }
            }
        }
    }

    private func weekdayColor(_ day: Date.WeekDay, progress: Double) -> Color {
        if isSameDate(day.date, currentDate) {
            return Color.white
        } else {
            return Colors.textGreenDark.color
        }
    }

    @ViewBuilder
    private func backgroundShape(_ day: Date.WeekDay) -> some View {
        if isSameDate(day.date, currentDate) {
            RoundedRectangle(cornerRadius: 35)
                .fill(Colors.greenBackgroundBright.color)
        } else if day.date.isToday {
            RoundedRectangle(cornerRadius: 35)
                .fill(Colors.greenBackgroundSoft.color)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func dayView(_ day: Date, progress: Double) -> some View {
        ZStack {
            Circle()
                .fill(getCircleColor(
                    day,
                    progress: progress,
                    isSelected: isSameDate(day, currentDate)
                ))
                .frame(width: 28, height: 28)
            CircularProgressBar(
                progress: .constant(progress),
                tintColor: getProgressColor(
                    day,
                    progress: progress,
                    isSelected: isSameDate(day, currentDate)
                ),
                size: 30,
                lineWidth: 3,
                placeholderColor: .clear
            )
            Text(day.format("dd"))
                .setFont(.semibold, size: 14)
                .foregroundStyle(
                    getDateColor(day, progress: progress, isSelected: isSameDate(day, currentDate))
                )
                .frame(width: 35, height: 35)
        }
        .overlay {
            if progress == 1.0 {
                Image(Images.Common.fire)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
                    .offset(y: 16)
            }
        }
    }

    private func getDateColor(
        _ day: Date,
        progress: Double,
        isSelected: Bool
    ) -> Color {
        return isSameDate(day, currentDate) || progress == 1.0 ? .white : Colors.textPrimary.color
    }

    private func getCircleColor(
        _ day: Date,
        progress: Double,
        isSelected: Bool
    ) -> Color {
        if isSelected && progress == 1.0 {
            return Color.clear
        } else if progress == 1.0 {
            return Color(hex: "58CC02")
        } else if isSelected {
            return Color.clear
        } else {
            return Color.white
        }
    }

    private func getProgressColor(
        _ day: Date,
        progress: Double,
        isSelected: Bool
    ) -> String {
        if isSelected || progress == 1.0 {
            return "FFFFFF"
        } else {
            return Colors.textGreenLight.rawValue
        }
    }
}

#Preview {
    WeekView(
        week: Date().fetchWeek(),
        currentDate: .constant(Date()),
        createWeek: .constant(false),
        paginateWeek: {}
    )
    .background(
        Color(hex: "F5F5F5")
    )
}
