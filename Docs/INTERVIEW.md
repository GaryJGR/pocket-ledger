# Project presentation

## Short pitch

Pocket Ledger is an iPhone bookkeeping prototype built with SwiftUI. It turns a natural-language expense into an editable transaction and compares monthly spending. It integrates Apple's on-device Foundation Models, with explicit availability handling and a basic offline parser. Money and monthly totals are calculated deterministically in Swift.

## Resume bullets

- Built a SwiftUI iPhone bookkeeping prototype with editable transaction review, local JSON persistence, native navigation, and light/dark appearance.
- Integrated Apple Foundation Models for structured natural-language transaction extraction and summaries of calculated monthly aggregates, with an explicit non-AI fallback.
- Implemented integer-cent amount validation, aligned month-to-date comparisons, and isolated fictional demo data for reproducible presentations.

## Explain these decisions

- Integer cents: avoid binary floating-point arithmetic for saved money.
- Review before save: extraction can be wrong; users can correct any field.
- Structured generation: produce typed fields instead of parsing arbitrary model prose.
- Deterministic statistics: AI receives already calculated facts and explains them.
- Availability checks: the app remains usable without the system model.
- Atomic JSON writes: a failed write does not first replace in-memory entries; unreadable files are preserved.
- Demo isolation: interview sample data is never merged into the personal ledger.

## Honest scope

This is an early prototype built with AI coding assistance and hands-on implementation/learning. Explain the pieces you understand; do not claim production scale, perfect extraction accuracy, or independent authorship of every line. Current date handling supports today/yesterday plus manual correction. Model-generated insights can still contain errors.
