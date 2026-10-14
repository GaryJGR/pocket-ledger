import SwiftUI
import Charts

struct ContentView: View {
    @State private var store = LedgerStore()
    @AppStorage("appearance") private var appearance = "System"
    @State private var input = ""
    @State private var month = Date.now
    @State private var draft: Transaction?
    @State private var reviewSource = "Manual entry"
    @State private var busy = false
    @State private var insightBusy = false
    @State private var aiInsight: String?
    @State private var insightError: String?
    @State private var pendingDelete: Transaction?
    private let accent = Color.teal
    private var summary: MonthSummary { MonthSummary(entries: store.entries, month: month) }
    private var monthEntries: [Transaction] {
        store.entries.filter { Calendar.current.isDate($0.date, equalTo: month, toGranularity: .month) }.sorted { $0.date > $1.date }
    }

    var body: some View {
        TabView {
            Tab("Overview", systemImage: "square.grid.2x2.fill") {
                NavigationStack { overview.navigationTitle("Pocket Ledger") }
            }
            Tab("Activity", systemImage: "list.bullet.rectangle") {
                NavigationStack { activity.navigationTitle("Activity") }
            }
            Tab("Settings", systemImage: "slider.horizontal.3") {
                NavigationStack { settings.navigationTitle("Settings") }
            }
        }
        .tint(accent)
        .preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        .sheet(item: $draft) { entry in
            EntryEditor(entry: entry, source: reviewSource) { edited in
                if store.save(edited) { input = ""; return true }
                return false
            }
        }
        .alert("Could not complete action", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(store.errorMessage ?? "") }
        .confirmationDialog("Delete this transaction?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete Transaction", role: .destructive) { if let entry = pendingDelete { store.delete(entry) }; pendingDelete = nil }
        }
        .onChange(of: summary.facts) { aiInsight = nil; insightError = nil }
        .onChange(of: store.isDemo) { aiInsight = nil; insightError = nil }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label(store.isDemo ? "DEMO WORKSPACE" : "PERSONAL WORKSPACE", systemImage: store.isDemo ? "sparkles" : "lock.shield")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Text("CAD").font(.caption.weight(.bold)).foregroundStyle(accent)
                }
                monthPicker
                balanceCard
                quickEntry
                comparisonCard
                categoryCard
                if !monthEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent activity").font(.title3.bold())
                        ForEach(Array(monthEntries.prefix(3))) { entry in
                            Button { reviewSource = "Edit transaction"; draft = entry } label: { entryRow(entry) }
                                .buttonStyle(.plain)
                        }
                    }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 24))
                }
                Text(store.isDemo ? "Fictional sample data. Changes in Demo are temporary." : "Your entries stay on this device.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
            .padding(20).frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.teal.opacity(0.045))
    }

    private var monthPicker: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 32) }
                .accessibilityLabel("Next month")
                .disabled(Calendar.current.isDate(month, equalTo: .now, toGranularity: .month))
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Recorded cash flow", systemImage: "waveform.path").font(.subheadline)
            Text(money(summary.income - summary.expenses))
                .font(.system(size: 38, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
            HStack {
                metric("Income", value: money(summary.income), icon: "arrow.down.left")
                Spacer()
                metric("Spending", value: money(summary.expenses), icon: "arrow.up.right")
            }
            Text(summary.period).font(.caption).opacity(0.8)
        }
        .foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.05, green: 0.39, blue: 0.38), Color(red: 0.04, green: 0.24, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
    }

    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon).font(.caption).opacity(0.8)
            Text(value).font(.headline).monospacedDigit()
        }
    }

    private var quickEntry: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("A sentence is all it takes", systemImage: "sparkles").font(.title3.bold())
            TextField("Lunch $18 yesterday", text: $input, axis: .vertical)
                .lineLimit(2...4).padding(14)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Transaction description")
            HStack {
                Button {
                    busy = true
                    Task {
                        defer { busy = false }
                        do {
                            let result = try await IntelligenceService.review(input)
                            reviewSource = result.1; draft = result.0
                        } catch { store.errorMessage = error.localizedDescription }
                    }
                } label: {
                    Label(busy ? "Understanding…" : "Review Entry", systemImage: "sparkles")
                }
                .buttonStyle(.glassProminent)
                .disabled(busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button("Manual") { newEntry() }.buttonStyle(.glass)
            }
            Text(IntelligenceService.status).font(.caption).foregroundStyle(.secondary)
            Text("One transaction at a time. Review the date and currency before saving.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Monthly perspective").font(.title3.bold())
                Spacer()
                Image(systemName: "chart.bar.xaxis").foregroundStyle(accent)
            }
            Text(summary.period).font(.caption).foregroundStyle(.secondary)
            Chart {
                BarMark(x: .value("Month", "Previous"), y: .value("CAD", Double(summary.priorExpenses) / 100))
                    .foregroundStyle(Color.teal.opacity(0.35)).cornerRadius(6)
                BarMark(x: .value("Month", "Selected"), y: .value("CAD", Double(summary.expenses) / 100))
                    .foregroundStyle(Color.teal).cornerRadius(6)
            }.frame(height: 130)
            if summary.current.isEmpty || summary.previous.isEmpty {
                Text("Add records in both months for a meaningful comparison.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Recorded spending is \(money(abs(summary.difference))) \(summary.difference >= 0 ? "higher" : "lower") than the previous period.")
                    .font(.subheadline)
            }
            Divider()
            Label("On-device insights", systemImage: "sparkles").font(.headline)
            if let aiInsight { Text(aiInsight).font(.subheadline).textSelection(.enabled) }
            else { Text("Turn your monthly totals into a short, readable explanation.").font(.subheadline).foregroundStyle(.secondary) }
            if let insightError { Text(insightError).font(.caption).foregroundStyle(.orange) }
            Button(insightBusy ? "Writing insight…" : "Explain This Month") {
                let facts = summary.facts
                let demo = store.isDemo
                insightBusy = true; insightError = nil
                Task {
                    defer { insightBusy = false }
                    do {
                        let result = try await IntelligenceService.insight(facts: facts)
                        if facts == summary.facts && demo == store.isDemo { aiInsight = result }
                    } catch { insightError = "AI could not generate an insight. The chart and totals above remain available." }
                }
            }.buttonStyle(.glass).disabled(insightBusy || !IntelligenceService.available || summary.current.isEmpty)
            if !IntelligenceService.available {
                Text("Apple Intelligence is unavailable here. The comparison above is calculated locally, without AI.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where it went").font(.title3.bold())
            if summary.categories.isEmpty {
                Text("Your spending categories will appear here.").foregroundStyle(.secondary)
            }
            ForEach(summary.categories, id: \.name) { category in
                VStack(spacing: 7) {
                    HStack { Text(category.name); Spacer(); Text(money(category.cents)).monospacedDigit() }.font(.subheadline)
                    ProgressView(value: Double(category.cents), total: Double(max(summary.expenses, 1))).tint(accent)
                }
            }
        }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    private var activity: some View {
        List {
            Section { monthPicker }
            Section(store.isDemo ? "Demo transactions" : "Your transactions") {
                if monthEntries.isEmpty { ContentUnavailableView("No entries yet", systemImage: "tray", description: Text("Add your first transaction to get started.")) }
                ForEach(monthEntries) { entry in
                    Button { reviewSource = "Edit transaction"; draft = entry } label: { entryRow(entry) }.buttonStyle(.plain)
                        .swipeActions { Button("Delete", role: .destructive) { pendingDelete = entry } }
                        .contextMenu { Button("Delete", role: .destructive) { pendingDelete = entry } }
                }
            }
        }
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Add", systemImage: "plus") { newEntry() } } }
    }

    private func entryRow(_ entry: Transaction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.symbol).foregroundStyle(accent).frame(width: 42, height: 42)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(entry.category) · \(entry.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entry.kind == .income ? "+" : "−")\(money(entry.amountInCents))")
                .font(.subheadline.weight(.semibold)).foregroundStyle(entry.kind == .income ? accent : .primary)
        }
    }

    private var settings: some View {
        Form {
            Section("Workspace") {
                Toggle("Demo workspace", isOn: Binding(get: { store.isDemo }, set: { store.setDemo($0) }))
                Text("Demo uses fictional transactions and resets when reopened. Turn it off to use your own persistent ledger.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Intelligence & privacy") {
                Label(IntelligenceService.status, systemImage: "sparkles")
                Text("When available, Apple Foundation Models runs on device. No API key or external server is used. Otherwise, simple entries use a labeled rule-based parser.")
                Text("Personal transactions are stored locally in the app container. This prototype has no bank connection, cloud sync or additional file encryption.")
                Text("Currency: CAD. Quick Entry supports today and yesterday; use the review date picker for other dates.")
            }.font(.subheadline)
            Section("About") {
                LabeledContent("Version", value: "0.1 · Prototype")
                LabeledContent("Created by", value: "Guanrui (Gary) Jiang")
                Link("GitHub · GaryJGR", destination: URL(string: "https://github.com/GaryJGR")!)
            }
        }
    }
    private func shiftMonth(_ value: Int) {
        let start = Calendar.current.dateInterval(of: .month, for: month)!.start
        month = Calendar.current.date(byAdding: .month, value: value, to: start)!
    }
    private func newEntry() {
        reviewSource = "Manual entry"
        draft = Transaction(title: "", amountInCents: 0, kind: .expense, category: "Other", date: .now)
    }
}

struct EntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var entry: Transaction
    let source: String
    let onSave: (Transaction) -> Bool
    @State private var amount = ""
    @State private var saveFailed = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(source, systemImage: "checkmark.shield")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Transaction") {
                    TextField("Title", text: $entry.title)
                    TextField("Amount (CAD)", text: $amount)
                    Picker("Type", selection: $entry.kind) {
                        Text("Expense").tag(TransactionKind.expense)
                        Text("Income").tag(TransactionKind.income)
                    }
                    Picker("Category", selection: $entry.category) {
                        ForEach(Transaction.categories, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                }
                Section { Text("Check every field before saving. Amounts are in Canadian dollars.").font(.caption).foregroundStyle(.secondary) }
                if saveFailed { Text("Could not save. Your entry is still here; please try again.").foregroundStyle(.red) }
            }
            .navigationTitle("Review Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let cents = parseAmount(amount) else { return }
                        entry.amountInCents = cents
                        entry.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if onSave(entry) { dismiss() } else { saveFailed = true }
                    }.disabled(parseAmount(amount) == nil || entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { amount = entry.amountInCents == 0 ? "" : String(format: "%.2f", Double(entry.amountInCents) / 100) }
        .presentationDetents([.large])
    }
}

#Preview { ContentView() }
