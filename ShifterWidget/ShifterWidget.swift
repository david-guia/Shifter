//
//  ShifterWidget.swift
//  ShifterWidget
//
//  Widget affichant les 3 shifts les plus longs + stats du quarter fiscal
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    typealias Entry = ShifterEntry
    
    func placeholder(in context: Context) -> ShifterEntry {
        ShifterEntry(date: Date(), top3Shifts: [], quarterStats: QuarterStats(totalHours: 0, progress: 0, currentQuarter: 1))
    }

    func getSnapshot(in context: Context, completion: @escaping (ShifterEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ShifterEntry>) -> Void) {
        let entry = createEntry()
        
        // Rafraîchir toutes les heures
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func createEntry() -> ShifterEntry {
        let dataProvider = WidgetDataProvider.shared
        let top3Data = dataProvider.getTop3ShiftsWithStats()
        let stats = dataProvider.getQuarterStats()
        
        let top3Shifts = top3Data.map { data in
            ShiftWithStats(segment: data.segment, totalHours: data.totalHours, percentage: data.percentage, delta: data.delta)
        }
        
        return ShifterEntry(date: Date(), top3Shifts: top3Shifts, quarterStats: stats)
    }
}

// MARK: - Timeline Entry

struct ShiftWithStats {
    let segment: String
    let totalHours: String
    let percentage: Int
    let delta: String
}

struct ShifterEntry: TimelineEntry {
    let date: Date
    let top3Shifts: [ShiftWithStats]
    let quarterStats: QuarterStats
}

// MARK: - Widget Entry View

struct ShifterWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: ShifterEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Titre
            Text("Shifter")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.primary)
            
            if let longestShiftStats = entry.top3Shifts.first {
                VStack(spacing: 8) {
                    Text(longestShiftStats.segment)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    
                    Text(longestShiftStats.totalHours)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.blue)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(14)
        .containerBackground(Color(red: 0.933, green: 0.933, blue: 0.933), for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: ShifterEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("🏆 Top 3 Shifts")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.primary)
                Spacer()
                Text("Q\(entry.quarterStats.currentQuarter)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.secondary)
            }
            
            // Top 3 shifts
            if entry.top3Shifts.isEmpty {
                Text("Aucun shift ce quarter")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(entry.top3Shifts.enumerated()), id: \.offset) { index, shiftStats in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shiftStats.segment)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(shiftStats.totalHours)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.blue)
                                .frame(width: 55, alignment: .trailing)
                            
                            Text("\(shiftStats.percentage)%")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 38, alignment: .trailing)
                            
                            Text(shiftStats.delta)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(shiftStats.delta == "–" ? Color.secondary : (shiftStats.delta.hasPrefix("+") ? Color.green : Color.red))
                                .frame(width: 35, alignment: .center)
                        }
                        
                        if index < entry.top3Shifts.count - 1 {
                            Divider()
                                .background(Color.secondary.opacity(0.3))
                        }
                    }
                }
            }
        }
        .padding(14)
        .containerBackground(Color(red: 0.933, green: 0.933, blue: 0.933), for: .widget)
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: ShifterEntry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shifter")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary)
                    Text("Top 3 shifts du mois")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
            }
            
            // Top 3 shifts détaillés
            if entry.top3Shifts.isEmpty {
                Spacer()
                Text("Aucun shift ce quarter")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                Spacer()
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(entry.top3Shifts.enumerated()), id: \.offset) { index, shiftStats in
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(shiftStats.segment)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.primary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(shiftStats.totalHours)
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.blue)
                                    
                                    HStack(spacing: 8) {
                                        Text("\(shiftStats.percentage)%")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color.secondary)
                                        
                                        Text(shiftStats.delta)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(shiftStats.delta == "–" ? Color.secondary : (shiftStats.delta.hasPrefix("+") ? Color.green : Color.red))
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                        )
                    }
                }
            }
            
            Spacer()
            
            // Quarter stats
            VStack(spacing: 8) {
                HStack {
                    Text("Quarter Q\(entry.quarterStats.currentQuarter) • 2025")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Text("\(String(format: "%.1f", entry.quarterStats.totalHours))h")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.blue)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(uiColor: .systemGray5))
                            .frame(height: 12)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * (entry.quarterStats.progress / 100), height: 12)
                        
                        // Border
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                            .frame(height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("\(Int(entry.quarterStats.progress))% complété")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.secondary)
            }
            .padding(10)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 2)
            )
        }
        .padding(14)
        .containerBackground(Color(red: 0.933, green: 0.933, blue: 0.933), for: .widget)
    }
}

// MARK: - Widget Configuration

struct ShifterWidget: Widget {
    let kind: String = "ShifterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ShifterWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Shifter")
        .description("Top 3 shifts + progression du quarter fiscal")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    ShifterWidget()
} timeline: {
    ShifterEntry(date: .now, top3Shifts: [], quarterStats: QuarterStats(totalHours: 42.5, progress: 67, currentQuarter: 4))
}
