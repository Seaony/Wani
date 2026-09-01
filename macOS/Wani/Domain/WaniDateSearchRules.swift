import Foundation

enum WaniDateSearchRules {
    static func matchingDays(
        _ query: String,
        now: Date = .now,
        calendar: Calendar = .current,
        limit: Int = 3
    ) -> [Date] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let day = Int(trimmedQuery),
            (1...31).contains(day),
            limit > 0
        else { return [] }

        let today = calendar.startOfDay(for: now)
        var firstMonthComponents = calendar.dateComponents([.year, .month], from: today)
        firstMonthComponents.day = 1
        guard let firstMonth = calendar.date(from: firstMonthComponents) else { return [] }

        var matches: [Date] = []
        for monthOffset in 0..<60 where matches.count < limit {
            guard let month = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: firstMonth
            ) else { continue }

            let monthComponents = calendar.dateComponents([.year, .month], from: month)
            var candidateComponents = monthComponents
            candidateComponents.day = day
            guard let candidate = calendar.date(from: candidateComponents) else { continue }

            let resolvedComponents = calendar.dateComponents(
                [.year, .month, .day],
                from: candidate
            )
            guard
                resolvedComponents.year == monthComponents.year,
                resolvedComponents.month == monthComponents.month,
                resolvedComponents.day == day,
                candidate >= today
            else { continue }

            matches.append(candidate)
        }
        return matches
    }
}
