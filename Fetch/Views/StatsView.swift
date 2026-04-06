import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Download.dateCreated, order: .reverse) private var downloads: [Download]

    var body: some View {
        Group {
            if downloads.isEmpty {
                emptyState
            } else {
                statsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Design.Spacing.lg) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Text("No Statistics Yet")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text("Download some media to see stats")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(Design.Spacing.xxl)
    }

    // MARK: - Stats Content

    private var statsContent: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.xl) {
                summaryCards

                HStack(alignment: .top, spacing: Design.Spacing.lg) {
                    extractorChart
                    formatChart
                }

                timelineChart
            }
            .padding(Design.Spacing.xl)
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: Design.Spacing.lg) {
            SummaryCard(
                title: "Total Downloads",
                value: "\(downloads.count)",
                icon: "arrow.down.circle.fill",
                color: .blue
            )

            SummaryCard(
                title: "Total Size",
                value: formattedTotalSize,
                icon: "externaldrive.fill",
                color: .purple
            )

            SummaryCard(
                title: "Top Extractor",
                value: topExtractor ?? "N/A",
                icon: "globe",
                color: .orange
            )
        }
    }

    // MARK: - Extractor Bar Chart

    private var extractorChart: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Downloads by Extractor")
                .font(.headline)

            Chart(extractorData, id: \.name) { item in
                BarMark(
                    x: .value("Downloads", item.count),
                    y: .value("Extractor", item.name)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(Design.Radius.micro)
            }
            .chartXAxisLabel("Downloads", alignment: .center)
            .frame(minHeight: max(CGFloat(extractorData.count) * 32, 120))
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Format Pie Chart

    private var formatChart: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Format Distribution")
                .font(.headline)

            Chart(formatData, id: \.name) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Format", item.name))
                .cornerRadius(Design.Radius.micro)
            }
            .chartLegend(position: .bottom, spacing: Design.Spacing.sm)
            .frame(minHeight: 200)
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timeline Line Chart

    private var timelineChart: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Downloads Over Time")
                .font(.headline)

            Text("Last 30 days")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(timelineData, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Downloads", item.count)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", item.date, unit: .day),
                    y: .value("Downloads", item.count)
                )
                .foregroundStyle(Color.accentColor.opacity(0.1).gradient)
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 200)
        }
        .cardStyle()
    }

    // MARK: - Data Computation

    private var formattedTotalSize: String {
        let total = downloads.compactMap(\.fileSize).reduce(0, +)
        guard total > 0 else { return "N/A" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }

    private var topExtractor: String? {
        let grouped = Dictionary(grouping: downloads) { $0.extractor ?? "Unknown" }
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }

    private var extractorData: [ChartDataPoint] {
        let grouped = Dictionary(grouping: downloads) { $0.extractor ?? "Unknown" }
        return grouped.map { ChartDataPoint(name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }

    private var formatData: [ChartDataPoint] {
        let grouped = Dictionary(grouping: downloads) { item -> String in
            guard let desc = item.formatDescription?.lowercased() else { return "Unknown" }
            if desc.contains("mp4") { return "MP4" }
            if desc.contains("webm") { return "WebM" }
            if desc.contains("mp3") { return "MP3" }
            if desc.contains("m4a") { return "M4A" }
            if desc.contains("mkv") { return "MKV" }
            if desc.contains("opus") { return "Opus" }
            if desc.contains("flac") { return "FLAC" }
            if desc.contains("wav") { return "WAV" }
            return desc.prefix(8).uppercased()
        }
        return grouped.map { ChartDataPoint(name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var timelineData: [TimelineDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) else {
            return []
        }

        let recentDownloads = downloads.filter { $0.dateCreated >= thirtyDaysAgo }
        let grouped = Dictionary(grouping: recentDownloads) { download -> Date in
            calendar.startOfDay(for: download.dateCreated)
        }

        var result: [TimelineDataPoint] = []
        var current = calendar.startOfDay(for: thirtyDaysAgo)
        let end = calendar.startOfDay(for: now)

        while current <= end {
            let count = grouped[current]?.count ?? 0
            result.append(TimelineDataPoint(date: current, count: count))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return result
    }
}

// MARK: - Data Types

private struct ChartDataPoint: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

private struct TimelineDataPoint: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            HStack(spacing: Design.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
