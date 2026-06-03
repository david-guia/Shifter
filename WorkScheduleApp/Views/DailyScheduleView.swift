//
//  DailyScheduleView.swift
//  WorkScheduleApp
//
//  Vue journalière — liste chronologique des shifts du jour
//

import SwiftUI

struct DailyScheduleView: View {
    let shifts: [Shift]
    let selectedDate: Date

    var body: some View {
        let sorted = sortedShifts
        VStack(spacing: 0) {
            headerView
            if sorted.isEmpty {
                emptyView
            } else {
                scrollableRows(sorted)
                totalFooter(sorted)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.systemBlack, lineWidth: 3)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Sous-vues

    private var headerView: some View {
        HStack(spacing: 0) {
            Text("Segment")
                .font(.chicago14)
                .foregroundStyle(Color.systemWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

            Text("Horaire")
                .font(.chicago14)
                .foregroundStyle(Color.systemWhite)
                .frame(width: 120, alignment: .leading)

            Text("Durée")
                .font(.chicago14)
                .foregroundStyle(Color.systemWhite)
                .frame(width: 60, alignment: .leading)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(Color.systemBlack)
    }

    private func scrollableRows(_ sorted: [Shift]) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(sorted) { shift in
                    HStack(spacing: 0) {
                        Text(shift.segment)
                            .font(.chicago12)
                            .foregroundStyle(Color.systemBlack)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 16)

                        Text("\(shift.startTime.time)→\(shift.endTime.time)")
                            .font(.chicago12)
                            .foregroundStyle(Color.systemBlack)
                            .frame(width: 120, alignment: .leading)

                        Text(shift.durationFormatted)
                            .font(.chicago12)
                            .foregroundStyle(Color.systemBlack)
                            .frame(width: 60, alignment: .leading)
                            .padding(.trailing, 16)
                    }
                    .padding(.vertical, 12)
                    .background(Color.systemWhite)

                    Divider()
                        .background(Color.systemBlack.opacity(0.12))
                }
            }
        }
    }

    private var emptyView: some View {
        Text("Aucun shift ce jour")
            .font(.chicago12)
            .foregroundStyle(Color.systemGray)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Color.systemWhite)
    }

    private func totalFooter(_ sorted: [Shift]) -> some View {
        HStack(spacing: 0) {
            Text("TOTAL")
                .font(.chicago14)
                .foregroundStyle(Color.systemWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

            Text(totalRange(sorted))
                .font(.chicago14)
                .foregroundStyle(Color.systemWhite)
                .frame(width: 120, alignment: .leading)

            Text(totalDuration(sorted))
                .font(.chicago14)
                .foregroundStyle(Color.systemWhite)
                .frame(width: 60, alignment: .leading)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 14)
        .background(Color.systemBlack)
    }

    // MARK: - Calculs

    private var sortedShifts: [Shift] {
        shifts
            .filter { $0.segment != "Général" }
            .sorted { $0.startTime < $1.startTime }
    }

    private func totalRange(_ sorted: [Shift]) -> String {
        guard let first = sorted.first, let last = sorted.last else { return "—" }
        return "\(first.startTime.time)→\(last.endTime.time)"
    }

    private func totalDuration(_ sorted: [Shift]) -> String {
        let total = sorted.reduce(0.0) { $0 + $1.duration }
        let h = Int(total) / 3600
        let m = Int(total) % 3600 / 60
        return m > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(h)h"
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let start1 = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!
    let end1   = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today)!
    let start2 = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: today)!
    let end2   = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: today)!

    let shifts = [
        Shift(date: today, startTime: start1, endTime: end1, location: "—", segment: "Caisse"),
        Shift(date: today, startTime: start2, endTime: end2, location: "—", segment: "Épicerie"),
    ]

    return DailyScheduleView(shifts: shifts, selectedDate: today)
        .padding()
        .background(Color(red: 0.96, green: 0.93, blue: 0.86))
}
