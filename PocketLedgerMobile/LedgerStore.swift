import Foundation
import Observation

@Observable @MainActor
final class LedgerStore {
    private(set) var entries: [Transaction] = []
    var errorMessage: String?
    var isDemo = true
    private var personalEntries: [Transaction] = []
    private var canWrite = true
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appending(path: "PocketLedger", directoryHint: .isDirectory)
            .appending(path: "transactions.json")
        do {
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                personalEntries = try JSONDecoder().decode([Transaction].self, from: Data(contentsOf: self.fileURL))
            }
        } catch {
            canWrite = false
            errorMessage = "Your saved file could not be read. It has been preserved."
        }
        entries = Self.demoEntries()
    }

    func setDemo(_ enabled: Bool) {
        isDemo = enabled
        entries = enabled ? Self.demoEntries() : personalEntries
    }

    @discardableResult func save(_ entry: Transaction) -> Bool {
        var updated = entries
        if let index = updated.firstIndex(where: { $0.id == entry.id }) {
            updated[index] = entry
        } else { updated.append(entry) }
        return commit(updated)
    }

    func delete(_ entry: Transaction) {
        _ = commit(entries.filter { $0.id != entry.id })
    }

    private func commit(_ updated: [Transaction]) -> Bool {
        if !isDemo {
            guard canWrite else {
                errorMessage = "Saving is disabled to protect the unreadable file."
                return false
            }
            do {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(updated).write(to: fileURL, options: .atomic)
                personalEntries = updated
            } catch {
                errorMessage = "Could not save your changes: \(error.localizedDescription)"
                return false
            }
        }
        entries = updated
        return true
    }

    static func demoEntries(now: Date = .now) -> [Transaction] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .month, for: now)!.start
        let previous = calendar.date(byAdding: .month, value: -1, to: start)!
        let day = calendar.component(.day, from: now)
        let samples: [(String, Int, String, Int)] = [
            ("Groceries", 6840, "Groceries", 1), ("Coffee", 575, "Food", 2),
            ("Lunch with friends", 2450, "Food", 3), ("Metro pass", 6200, "Transport", 4),
            ("Weekly groceries", 8235, "Groceries", 6), ("Dinner", 3870, "Food", 8),
            ("Music subscription", 1199, "Subscriptions", 9), ("Coffee & pastry", 1120, "Food", 11)
        ]
        var result: [Transaction] = []
        for (offset, month) in [start, previous].enumerated() {
            for (title, cents, category, sampleDay) in samples where sampleDay <= day {
                result.append(Transaction(title: title, amountInCents: offset == 0 ? cents : cents * 4 / 5,
                                          kind: .expense, category: category,
                                          date: calendar.date(byAdding: .day, value: sampleDay - 1, to: month)!))
            }
            result.append(Transaction(title: "Part-time pay", amountInCents: 125000, kind: .income,
                                      category: "Income", date: month))
        }
        return result
    }
}

extension Transaction {
    static let categories = ["Food", "Groceries", "Transport", "Shopping", "Subscriptions", "Housing", "Health", "Entertainment", "Income", "Other"]
    var symbol: String {
        switch category {
        case "Food": "fork.knife"
        case "Groceries": "basket.fill"
        case "Transport": "tram.fill"
        case "Shopping": "bag.fill"
        case "Subscriptions": "repeat"
        case "Housing": "house.fill"
        case "Health": "heart.fill"
        case "Entertainment": "ticket.fill"
        case "Income": "arrow.down.left"
        default: "ellipsis"
        }
    }
}

func money(_ cents: Int) -> String {
    (Decimal(cents) / 100).formatted(.currency(code: "CAD"))
}

func parseAmount(_ text: String) -> Int? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard value.range(of: #"^[0-9]{1,7}(\.[0-9]{1,2})?$"#, options: .regularExpression) != nil else { return nil }
    let parts = value.split(separator: ".")
    guard let whole = Int(parts[0]) else { return nil }
    let fraction = parts.count == 2 ? String(parts[1]) : ""
    let cents = whole * 100 + (Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0)
    return cents > 0 ? cents : nil
}

struct MonthSummary {
    let current: [Transaction]
    let previous: [Transaction]
    let period: String
    init(entries: [Transaction], month: Date, now: Date = .now) {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .month, for: month)!.start
        let next = cal.date(byAdding: .month, value: 1, to: start)!
        let prior = cal.date(byAdding: .month, value: -1, to: start)!
        let isCurrent = cal.isDate(month, equalTo: now, toGranularity: .month)
        let day = cal.component(.day, from: now)
        let lastPriorDay = cal.range(of: .day, in: .month, for: prior)!.count
        let cutoff = isCurrent ? min(day, lastPriorDay) : 31
        current = entries.filter { $0.date >= start && $0.date < next && (!isCurrent || cal.component(.day, from: $0.date) <= cutoff) }
        previous = entries.filter { $0.date >= prior && $0.date < start && (!isCurrent || cal.component(.day, from: $0.date) <= cutoff) }
        period = isCurrent ? "Days 1–\(cutoff) in both months" : "Full calendar months"
    }
    var expenses: Int { current.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountInCents } }
    var income: Int { current.filter { $0.kind == .income }.reduce(0) { $0 + $1.amountInCents } }
    var priorExpenses: Int { previous.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountInCents } }
    var difference: Int { expenses - priorExpenses }
    var categories: [(name: String, cents: Int)] {
        Dictionary(grouping: current.filter { $0.kind == .expense }, by: \.category)
            .map { (name: $0.key, cents: $0.value.reduce(0) { $0 + $1.amountInCents }) }
            .sorted { $0.cents > $1.cents }
    }
    var facts: String {
        "\(period). Recorded spending: \(money(expenses)); previous month: \(money(priorExpenses)); change: \(money(difference)). Recorded income: \(money(income)). Categories: " + categories.map { "\($0.name): \(money($0.cents))" }.joined(separator: "; ")
    }
}
