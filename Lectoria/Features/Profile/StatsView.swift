import SwiftUI
import Charts
import os

private let logger = Logger(subsystem: "com.orvexa.Lectoria", category: "Stats")

// MARK: - StatsView

/// Estadísticas de lectura (Perfil → Estadísticas).
///
/// Todo se calcula en el dispositivo a partir de las sesiones de lectura guardadas,
/// con `ReadingStatsCalculator`. Sin gamificación invasiva: solo información y una meta opcional.
struct StatsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @AppStorage("weeklyReadingGoalMinutes") private var weeklyGoal = 120

    @State private var stats: ReadingStats? = nil
    // Datos crudos: se conservan para recalcular al cambiar la meta sin volver a leer la base.
    @State private var sessions: [ReadingSession] = []
    @State private var publications: [PublicationRecord] = []
    @State private var progress: [UUID: Double] = [:]
    @State private var loadFailed = false

    var body: some View {
        let theme = themeManager.currentTheme

        ScrollView {
            if loadFailed {
                ContentUnavailableView(
                    String(localized: "No se pudieron cargar las estadísticas", comment: "Stats: load error title"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(String(localized: "Tu historial de lectura sigue guardado. Vuelve a abrir esta pantalla en un momento.", comment: "Stats: load error description"))
                )
                .padding(.top, AppSpacing.xxxl)
            } else if let stats {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    MascotSlotView(message: ReadingStatsCalculator.mascotMessage(for: stats), theme: theme)
                    weeklyGoalSection(stats, theme: theme)
                    shelfChart(stats, theme: theme)
                    summarySection(stats, theme: theme)
                    if !stats.topPublications.isEmpty {
                        topSection(stats, theme: theme)
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.lg)
            } else {
                ProgressView()
                    .tint(AppColor.accent(for: theme))
                    .padding(.top, AppSpacing.xxxl)
            }
        }
        .background(AppColor.background(for: theme))
        .navigationTitle(String(localized: "Estadísticas", comment: "Stats screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: weeklyGoal) { _, _ in recompute() }
    }

    // MARK: - Meta semanal

    private func weeklyGoalSection(_ stats: ReadingStats, theme: AppTheme) -> some View {
        let fraction = min(1, Double(stats.weekMinutes) / Double(max(1, stats.weeklyGoalMinutes)))
        let reached = stats.weekMinutes >= stats.weeklyGoalMinutes

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(String(localized: "Esta semana", comment: "Stats: weekly section title"))
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary(for: theme))

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                Text("\(stats.weekMinutes)")
                    .font(.system(size: 40, weight: .semibold, design: .serif))
                    .monospacedDigit()
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                Text(String(localized: "de \(stats.weeklyGoalMinutes) min", comment: "Stats: minutes out of weekly goal"))
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.surfaceSecondary(for: theme))
                    Capsule()
                        .fill(reached ? AppColor.success(for: theme) : AppColor.accent(for: theme))
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
            .accessibilityElement()
            .accessibilityLabel(String(localized: "Meta semanal", comment: "Stats: weekly goal a11y label"))
            .accessibilityValue(String(localized: "\(stats.weekMinutes) de \(stats.weeklyGoalMinutes) minutos", comment: "Stats: weekly goal a11y value"))

            if reached {
                Text(String(localized: "Meta de la semana cumplida", comment: "Stats: weekly goal reached"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColor.success(for: theme))
            }

            Stepper(value: $weeklyGoal, in: 15...1500, step: 15) {
                Text(String(localized: "Meta semanal: \(weeklyGoal) min", comment: "Stats: weekly goal stepper"))
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }
        }
    }

    // MARK: - Estante de los últimos 7 días

    /// Cada día es un lomo de libro sobre un estante; el de hoy, en el color de acento.
    private func shelfChart(_ stats: ReadingStats, theme: AppTheme) -> some View {
        let today = stats.last7Days.last?.date
        let maxMinutes = max(stats.last7Days.map(\.minutes).max() ?? 0, 10)

        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(String(localized: "Últimos 7 días", comment: "Stats: last 7 days title"))
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary(for: theme))

            Chart {
                ForEach(stats.last7Days) { day in
                BarMark(
                    x: .value("Día", day.date, unit: .day),
                    y: .value("Minutos", day.minutes),
                    width: .ratio(0.55)
                )
                .cornerRadius(5)
                .foregroundStyle(
                    day.date == today
                        ? AppColor.accent(for: theme)
                        : AppColor.accent(for: theme).opacity(0.45)
                )
                .annotation(position: .top, spacing: 4) {
                    if day.minutes > 0 {
                        Text("\(day.minutes)")
                            .font(AppTypography.caption)
                            .monospacedDigit()
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                }
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).locale(Self.appLocale)))
                .accessibilityValue(String(localized: "\(day.minutes) minutos", comment: "Stats: chart bar a11y value"))
                }

                // El estante sobre el que se apoyan los "lomos".
                RuleMark(y: .value("Estante", 0))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(AppColor.textTertiary(for: theme))
                    .accessibilityHidden(true)
            }
            .chartYScale(domain: 0...Double(maxMinutes) * 1.2)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: stats.last7Days.map(\.date)) { value in
                    AxisValueLabel(centered: true) {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.weekday(.narrow).locale(Self.appLocale)))
                                .font(date == today ? AppTypography.captionBold : AppTypography.caption)
                                .foregroundStyle(
                                    date == today ? AppColor.accent(for: theme) : AppColor.textSecondary(for: theme)
                                )
                        }
                    }
                }
            }
            .frame(height: 170)
        }
    }

    // MARK: - Resumen

    private func summarySection(_ stats: ReadingStats, theme: AppTheme) -> some View {
        VStack(spacing: 0) {
            summaryRow(icon: "flame", label: String(localized: "Racha actual", comment: "Stats: current streak"),
                       value: daysText(stats.currentStreak), theme: theme)
            Divider()
            summaryRow(icon: "calendar", label: String(localized: "Días activos este mes", comment: "Stats: active days this month"),
                       value: daysText(stats.activeDaysThisMonth), theme: theme)
            Divider()
            summaryRow(icon: "clock", label: String(localized: "Tiempo total leído", comment: "Stats: total reading time"),
                       value: durationText(stats.totalMinutes), theme: theme)
            Divider()
            summaryRow(icon: "book", label: String(localized: "Documentos empezados", comment: "Stats: started documents"),
                       value: "\(stats.startedCount)", theme: theme)
            Divider()
            summaryRow(icon: "checkmark.seal", label: String(localized: "Documentos terminados", comment: "Stats: finished documents"),
                       value: "\(stats.finishedCount)", theme: theme)
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func summaryRow(icon: String, label: String, value: String, theme: AppTheme) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppColor.accent(for: theme))
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textPrimary(for: theme))
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(AppTypography.bodyBold)
                .monospacedDigit()
                .foregroundStyle(AppColor.textPrimary(for: theme))
        }
        .padding(.vertical, AppSpacing.md)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Más leídos

    private func topSection(_ stats: ReadingStats, theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(String(localized: "Más leídos", comment: "Stats: most read title"))
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary(for: theme))

            VStack(spacing: 0) {
                ForEach(Array(stats.topPublications.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider() }
                    HStack(spacing: AppSpacing.md) {
                        Text("\(index + 1)")
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .foregroundStyle(AppColor.accent(for: theme))
                            .frame(width: 24)
                        Text(item.title)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
                            .lineLimit(2)
                        Spacer(minLength: AppSpacing.sm)
                        Text(durationText(item.minutes))
                            .font(AppTypography.callout)
                            .monospacedDigit()
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                    .padding(.vertical, AppSpacing.md)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        }
    }

    // MARK: - Formato

    /// Los textos de la app están en español (aunque el proyecto declare `en` como región de
    /// desarrollo), así que los nombres de los días se fijan en español para no mezclar idiomas.
    private static let appLocale = Locale(identifier: "es")

    private func daysText(_ days: Int) -> String {
        days == 1
            ? String(localized: "1 día", comment: "Stats: one day")
            : String(localized: "\(days) días", comment: "Stats: N days")
    }

    private func durationText(_ minutes: Int) -> String {
        guard minutes >= 60 else {
            return String(localized: "\(minutes) min", comment: "Stats: minutes")
        }
        return String(localized: "\(minutes / 60) h \(minutes % 60) min", comment: "Stats: hours and minutes")
    }

    // MARK: - Datos

    private func load() async {
        do {
            sessions = try await dependencies.readingSessionRepository.fetchAll()
            publications = try await dependencies.publicationRepository.fetchAll()
            var progressByID: [UUID: Double] = [:]
            for publication in publications {
                if let value = try? await dependencies.readingProgressRepository.fetchProgress(forPublication: publication.id) {
                    progressByID[publication.id] = value.percentage
                }
            }
            progress = progressByID
        } catch {
            logger.error("No se pudieron cargar las estadísticas: \(error.localizedDescription)")
            loadFailed = true
            return
        }
        recompute()
    }

    private func recompute() {
        stats = ReadingStatsCalculator.compute(
            sessions: sessions,
            publications: publications,
            progressByPublication: progress,
            weeklyGoalMinutes: weeklyGoal,
            now: Date(),
            calendar: .current
        )
    }
}
