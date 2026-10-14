#if DEBUG
import Foundation

@MainActor enum PrototypeChecks {
    static func run() {
        assert(parseAmount("18.50") == 1850)
        assert(parseAmount("0.01") == 1)
        assert(parseAmount("1.001") == nil)
        assert(parseAmount("-5") == nil)
        assert(parseAmount("0") == nil)
        assert(parseAmount("1,200") == nil)
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appending(path: "transactions.json")
        let store = LedgerStore(fileURL: url)
        store.setDemo(false)
        let entry = Transaction(title: "Persistence check", amountInCents: 1850, kind: .expense, category: "Food", date: .now)
        assert(store.save(entry))
        let loaded = LedgerStore(fileURL: url)
        loaded.setDemo(false)
        assert(loaded.entries.count == 1 && loaded.entries[0].amountInCents == 1850)
        loaded.setDemo(true)
        _ = loaded.save(Transaction(title: "Demo only", amountInCents: 100, kind: .expense, category: "Other", date: .now))
        loaded.setDemo(false)
        assert(loaded.entries.count == 1)
        loaded.delete(entry)
        let empty = LedgerStore(fileURL: url)
        empty.setDemo(false)
        assert(empty.entries.isEmpty)
        do {
            let corrupt = Data("invalid JSON".utf8)
            try corrupt.write(to: url)
            let protected = LedgerStore(fileURL: url)
            protected.setDemo(false)
            assert(!protected.save(entry))
            let preserved = try Data(contentsOf: url)
            assert(preserved == corrupt)
        } catch { assertionFailure("Persistence checks failed: \(error)") }
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 12))!
        func record(_ month: Int, _ day: Int, _ amount: Int) -> Transaction {
            Transaction(title: "Boundary", amountInCents: amount, kind: .expense, category: "Other",
                        date: cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!)
        }
        let summary = MonthSummary(entries: [record(3, 28, 100), record(3, 29, 999), record(2, 28, 200)], month: now, now: now)
        assert(summary.expenses == 100 && summary.priorExpenses == 200)
        print("Pocket Ledger checks passed: exact cents, persistence, demo isolation, deletion, corrupt-file preservation, month boundaries.")
    }
}
#endif
